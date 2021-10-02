# frozen_string_literal: true

require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/util/byte_number'
require 'vagrant-libvirt/action/create_domain'

describe VagrantPlugins::ProviderLibvirt::Action::CreateDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:libvirt_client) { double('libvirt_client') }
  let(:servers) { double('servers') }
  let(:volumes) { double('volumes') }
  let(:domain_volume) { double('domain_volume') }

  let(:domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), domain_xml_file)) }
  let(:storage_pool_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), storage_pool_xml_file)) }
  let(:libvirt_storage_pool) { double('storage_pool') }

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:client).and_return(libvirt_client)

      allow(connection).to receive(:servers).and_return(servers)
      allow(connection).to receive(:volumes).and_return(volumes)
      allow(volumes).to receive(:all).and_return([domain_volume])
      allow(domain_volume).to receive(:pool_name).and_return('default')
      allow(domain_volume).to receive(:path).and_return('/var/lib/libvirt/images/vagrant-test_default.img')
      allow(machine).to receive_message_chain("box.name") { 'vagrant-libvirt/test' }

      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)
      allow(ui).to receive(:info)

      env[:domain_name] = "vagrant-test_default"

      env[:box_volumes] = []
      env[:box_volumes].push({
        :path=>"/test/box.img",
        :name=>"test_vagrant_box_image_1.1.1_0.img", 
        :virtual_size=> ByteNumber.new(5),
      })
      # should be ignored for system session and used for user session
      allow(Process).to receive(:uid).and_return(9999)
      allow(Process).to receive(:gid).and_return(9999)
    end

    context 'connection => qemu:///system' do
      let(:domain_xml_file) { 'default_domain.xml' }

      context 'default pool' do
        it 'should execute correctly' do
          expect(servers).to receive(:create).with(xml: domain_xml).and_return(machine)
          expect(volumes).to_not receive(:create) # additional disks only

          expect(subject.call(env)).to be_nil
        end

        context 'with no box' do
          let(:storage_pool_xml_file) { 'default_system_storage_pool.xml' }
          let(:vagrantfile) do
            <<-EOF
            Vagrant.configure('2') do |config|
              config.vm.define :test
            end
            EOF
          end

          it 'should query for the storage pool path' do
            expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(libvirt_storage_pool)
            expect(libvirt_storage_pool).to receive(:xml_desc).and_return(storage_pool_xml)
            expect(servers).to receive(:create).and_return(machine)

            expect(subject.call(env)).to be_nil
          end
        end

        context 'additional disks' do
          let(:vagrantfile_providerconfig) do
            <<-EOF
            libvirt.storage :file, :size => '20G'
            EOF
          end

          context 'volume create failed' do
            it 'should raise an exception' do
              expect(volumes).to receive(:create).and_raise(Libvirt::Error)

              expect{ subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::FogCreateDomainVolumeError)
            end
          end

          context 'volume create succeeded' do
            let(:domain_xml_file) { 'additional_disks_domain.xml' }

            it 'should complete' do
              expect(volumes).to receive(:create).with(
                hash_including(
                  :path        => "/var/lib/libvirt/images/vagrant-test_default-vdb.qcow2",
                  :owner       => 0,
                  :group       => 0,
                  :pool_name   => "default",
                )
              )
              expect(servers).to receive(:create).with(xml: domain_xml).and_return(machine)

              expect(subject.call(env)).to be_nil
            end
          end
        end

        context 'with custom disk device setting' do
          let(:domain_xml_file) { 'custom_disk_settings.xml' }
          let(:vagrantfile_providerconfig) {
            <<-EOF
              libvirt.disk_device = 'sda'
            EOF
          }

          it 'should set the domain device' do
            expect(ui).to receive(:info).with(/ -- Image\(sda\):.*/)
            expect(servers).to receive(:create).with(xml: domain_xml).and_return(machine)

            expect(subject.call(env)).to be_nil
          end
        end

        context 'with two domain disks' do
          let(:domain_xml_file) { 'two_disk_settings.xml' }
          let(:domain_volume_2) { double('domain_volume 2') }

          before do
            expect(volumes).to receive(:all).and_return([domain_volume])
            expect(volumes).to receive(:all).and_return([domain_volume_2])
            expect(domain_volume_2).to receive(:pool_name).and_return('default')
            expect(domain_volume_2).to receive(:path).and_return('/var/lib/libvirt/images/vagrant-test_default_1.img')

            env[:box_volumes].push({
              :path=>"/test/box_1.img",
              :name=>"test_vagrant_box_image_1.1.1_1.img",
              :virtual_size=> ByteNumber.new(5),
            })
          end

          it 'should correctly assign device entries' do
            expect(ui).to receive(:info).with(/ -- Image\(vda\):.*/)
            expect(ui).to receive(:info).with(/ -- Image\(vdb\):.*/)
            expect(servers).to receive(:create).with(xml: domain_xml).and_return(machine)

            expect(subject.call(env)).to be_nil
          end
        end
      end

      context 'no default pool' do
        let(:vagrantfile) do
          <<-EOF
          Vagrant.configure('2') do |config|
            config.vm.define :test
          end
          EOF
        end

        it 'should raise an exception' do
          expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(nil)

          expect{ subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::NoStoragePool)
        end
      end
    end

    context 'connection => qemu:///session' do
      let(:vagrantfile_providerconfig) do
        <<-EOF
        libvirt.qemu_use_session = true
        EOF
      end

      context 'default pool' do
        it 'should execute correctly' do
          expect(servers).to receive(:create).and_return(machine)

          expect(subject.call(env)).to be_nil
        end

        context 'with no box' do
          let(:storage_pool_xml_file) { 'default_user_storage_pool.xml' }
          let(:vagrantfile) do
            <<-EOF
            Vagrant.configure('2') do |config|
              config.vm.define :test
              config.vm.provider :libvirt do |libvirt|
                #{vagrantfile_providerconfig}
              end
            end
            EOF
          end

          it 'should query for the storage pool path' do
            expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(libvirt_storage_pool)
            expect(libvirt_storage_pool).to receive(:xml_desc).and_return(storage_pool_xml)
            expect(servers).to receive(:create).and_return(machine)

            expect(subject.call(env)).to be_nil
          end
        end

        context 'additional disks' do
          let(:vagrantfile_providerconfig) do
            <<-EOF
            libvirt.qemu_use_session = true
            libvirt.storage :file, :size => '20G'
            EOF
          end

          context 'volume create succeeded' do
            it 'should complete' do
              expect(volumes).to receive(:create).with(
                hash_including(
                  :path        => "/var/lib/libvirt/images/vagrant-test_default-vdb.qcow2",
                  :owner       => 9999,
                  :group       => 9999,
                  :pool_name   => "default",
                )
              )
              expect(servers).to receive(:create).and_return(machine)

              expect(subject.call(env)).to be_nil
            end
          end
        end
      end
    end
  end
end
