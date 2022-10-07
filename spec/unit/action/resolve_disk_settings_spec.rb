# frozen_string_literal: true

require 'spec_helper'

require 'fog/libvirt/models/compute/volume'

require 'vagrant-libvirt/action/resolve_disk_settings'

describe VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:servers) { double('servers') }
  let(:volumes) { double('volumes') }
  let(:domain_volume) { instance_double(::Fog::Libvirt::Compute::Volume) }
  let(:libvirt_storage_pool) { double('storage_pool') }

  let(:domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), domain_xml_file)) }
  let(:storage_pool_xml) do
    File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), storage_pool_xml_file))
  end

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:debug)
  end

  describe '#call' do
    before do
      allow(connection).to receive(:volumes).and_return(volumes)
      allow(volumes).to receive(:all).and_return([domain_volume])
      allow(domain_volume).to receive(:pool_name).and_return('default')
      allow(domain_volume).to receive(:path).and_return('/var/lib/libvirt/images/vagrant-test_default.img')
    end

    context 'when vm box is in use' do
      context 'when box metadata is available' do
        let(:box_volumes) do
          [
            {
              path: '/test/box.img',
              name: 'test_vagrant_box_image_1.1.1_box.img',
            },
          ]
        end

        before do
          env[:domain_name] = 'vagrant-test_default'
          env[:box_volumes] = box_volumes
        end

        it 'should populate domain volume' do
          expect(subject.call(env)).to be_nil
          expect(env[:domain_volumes]).to match(
            [
              hash_including(
                device: 'vda',
                absolute_path: '/var/lib/libvirt/images/vagrant-test_default.img'
              ),
            ]
          )
        end

        context 'when additional storage specified' do
          let(:vagrantfile_providerconfig) do
            <<-EOF
              libvirt.storage :file, :size => '20G'
            EOF
          end

          it 'should use the next device for storage' do
            expect(subject.call(env)).to be_nil
            expect(env[:disks]).to match(
              [
                hash_including(
                  device: 'vdb',
                  absolute_path: '/var/lib/libvirt/images/vagrant-test_default-vdb.qcow2'
                ),
              ]
            )
          end
        end

        context 'when custom disk device setting' do
          before do
            machine.provider_config.disk_device = 'sda'
          end

          it 'should set the domain device' do
            expect(subject.call(env)).to be_nil
            expect(env[:domain_volumes]).to match(
              [
                hash_including(
                  device: 'sda',
                  absolute_path: '/var/lib/libvirt/images/vagrant-test_default.img'
                ),
              ]
            )
          end

          context 'when additional storage specified' do
            let(:vagrantfile_providerconfig) do
              <<-EOF
                libvirt.storage :file, :size => '20G'
              EOF
            end

            it 'should use the next custom disk device for storage' do
              expect(subject.call(env)).to be_nil
              expect(env[:disks]).to match(
                [
                  hash_including(
                    device: 'sdb',
                    absolute_path: '/var/lib/libvirt/images/vagrant-test_default-sdb.qcow2'
                  ),
                ]
              )
            end
          end
        end

        context 'when multiple box volumes' do
          let(:box_volumes) do
            [
              {
                path: '/test/box.img',
                name: 'test_vagrant_box_image_1.1.1_box.img',
              },
              {
                path: '/test/box_2.img',
                name: 'test_vagrant_box_image_1.1.1_box_2.img',
              },
            ]
          end
          it 'should populate all domain volumes' do
            expect(subject.call(env)).to be_nil
            expect(env[:domain_volumes]).to match(
              [
                hash_including(
                  device: 'vda',
                  absolute_path: '/var/lib/libvirt/images/vagrant-test_default.img'
                ),
                hash_including(
                  device: 'vdb',
                  absolute_path: '/var/lib/libvirt/images/vagrant-test_default.img'
                ),
              ]
            )
          end

          context 'when additional storage specified' do
            let(:vagrantfile_providerconfig) do
              <<-EOF
                libvirt.storage :file, :size => '20G'
              EOF
            end

            it 'should use the next device for storage' do
              expect(subject.call(env)).to be_nil
              expect(env[:disks]).to match(
                [
                  hash_including(
                    device: 'vdc',
                    absolute_path: '/var/lib/libvirt/images/vagrant-test_default-vdc.qcow2'
                  ),
                ]
              )
            end
          end
        end
      end

      context 'when box metadata is not available' do
        let(:domain_xml_file) { 'default_domain.xml' }

        before do
          expect(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)
        end

        it 'should query the domain xml' do
          expect(subject.call(env)).to be_nil
          expect(env[:domain_volumes]).to match(
            [
              hash_including(
                device: 'vda',
                absolute_path: '/var/lib/libvirt/images/vagrant-test_default.img'
              ),
            ]
          )
        end

        context 'when multiple volumes in domain config' do
          let(:domain_xml_file) { 'multi_volume_box.xml' }

          it 'should populate domain volumes with devices' do
            expect(subject.call(env)).to be_nil
            expect(env[:domain_volumes]).to match(
              [
                hash_including(
                  device: 'vda',
                  absolute_path: '/var/lib/libvirt/images/vagrant-test_default.img'
                ),
                hash_including(
                  device: 'vdb',
                  absolute_path: '/var/lib/libvirt/images/vagrant-test_default_1.img'
                ),
                hash_including(
                  device: 'vdc',
                  absolute_path: '/var/lib/libvirt/images/vagrant-test_default_2.img'
                ),
              ]
            )
          end

          context 'when additional storage in domain config' do
            let(:domain_xml_file) { 'multi_volume_box_additional_storage.xml' }
            let(:vagrantfile_providerconfig) do
              <<-EOF
                libvirt.storage :file, :size => '20G'
                libvirt.storage :file, :size => '20G'
              EOF
            end

            it 'should populate disks with devices' do
              expect(subject.call(env)).to be_nil
              expect(env[:disks]).to match(
                [
                  hash_including(
                    device: 'vdd',
                    absolute_path: '/var/lib/libvirt/images/vagrant-test_default-vdd.qcow2'
                  ),
                  hash_including(
                    device: 'vde',
                    absolute_path: '/var/lib/libvirt/images/vagrant-test_default-vde.qcow2'
                  ),
                ]
              )
            end
          end
        end

        context 'when no aliases available' do
          let(:domain_xml_file) { 'default_no_aliases.xml' }

          it 'should assume a single box volume' do
            expect(subject.call(env)).to be_nil
            expect(env[:domain_volumes]).to match(
              [
                hash_including(
                  device: 'vda',
                  absolute_path: '/var/lib/libvirt/images/vagrant-test_default.img'
                ),
              ]
            )
          end

          context 'when additional storage and a custom disk device attached' do
            let(:domain_xml_file) { 'multi_volume_box_additional_and_custom_no_aliases.xml' }
            let(:vagrantfile_providerconfig) do
              <<-EOF
                libvirt.storage :file, :size => '20G'
                libvirt.storage :file, :size => '20G'
              EOF
            end

            it 'should detect the domain volumes and disks while ignoring the last one' do
              expect(subject.call(env)).to be_nil
              expect(env[:domain_volumes]).to match(
                [
                  hash_including(
                    device: 'vda',
                    absolute_path: '/var/lib/libvirt/images/vagrant-test_default.img'
                  ),
                  hash_including(
                    device: 'vdb',
                    absolute_path: '/var/lib/libvirt/images/vagrant-test_default_1.img'
                  ),
                  hash_including(
                    device: 'vdc',
                    absolute_path: '/var/lib/libvirt/images/vagrant-test_default_2.img'
                  ),
                ]
              )
              expect(env[:disks]).to match(
                [
                  hash_including(
                    device: 'vdd',
                    absolute_path: '/var/lib/libvirt/images/vagrant-test_default-vdd.qcow2'
                  ),
                  hash_including(
                    device: 'vde',
                    absolute_path: '/var/lib/libvirt/images/vagrant-test_default-vde.qcow2'
                  ),
                ]
              )
            end
          end
        end
      end

      context 'no default pool' do
        let(:domain_xml_file) { 'default_domain.xml' }
        let(:vagrantfile) do
          <<-EOF
          Vagrant.configure('2') do |config|
            config.vm.define :test
          end
          EOF
        end

        it 'should raise an exception' do
          expect(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)
          expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(nil)

          expect { subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::NoStoragePool)
        end
      end
    end

    context 'when no box defined' do
      let(:domain_xml_file) { 'default_domain.xml' }
      let(:storage_pool_xml_file) { 'default_system_storage_pool.xml' }
      let(:vagrantfile) do
        <<-EOF
        Vagrant.configure('2') do |config|
          config.vm.define :test
          config.vm.provider :libvirt do |libvirt|
            libvirt.storage :file, :size => '20G'
          end
        end
        EOF
      end

      it 'should query for domain name and storage pool path' do
        expect(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)
        expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)
        expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(libvirt_storage_pool)
        expect(libvirt_storage_pool).to receive(:xml_desc).and_return(storage_pool_xml)

        expect(subject.call(env)).to be_nil
        expect(env[:disks]).to match(
          [
            hash_including(
              device: 'vda',
              cache: 'default',
              bus: 'virtio',
              path: 'vagrant-test_default-vda.qcow2',
              absolute_path: '/var/lib/libvirt/images/vagrant-test_default-vda.qcow2',
              size: '20G',
              pool: 'default'
            ),
          ]
        )
      end

      context 'when creating using pxe' do
        before do
          env[:domain_name] = 'vagrant-test_default'
        end

        it 'should not query for domain xml' do
          expect(libvirt_client).to_not receive(:lookup_domain_by_uuid)
          expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(libvirt_storage_pool)
          expect(libvirt_storage_pool).to receive(:xml_desc).and_return(storage_pool_xml)

          expect(subject.call(env)).to be_nil
          expect(env[:disks]).to match(
            [
              hash_including(
                device: 'vda',
                path: 'vagrant-test_default-vda.qcow2',
                absolute_path: '/var/lib/libvirt/images/vagrant-test_default-vda.qcow2',
                pool: 'default'
              ),
            ]
          )
        end
      end
    end
  end
end
