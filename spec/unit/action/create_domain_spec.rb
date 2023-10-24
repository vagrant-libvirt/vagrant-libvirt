# frozen_string_literal: true

require_relative '../../spec_helper'

require 'fog/libvirt/models/compute/volume'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/util/byte_number'
require 'vagrant-libvirt/action/create_domain'

describe VagrantPlugins::ProviderLibvirt::Action::CreateDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:servers) { double('servers') }
  let(:volumes) { double('volumes') }
  let(:domain_volume) { instance_double(::Fog::Libvirt::Compute::Volume) }

  let(:domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), domain_xml_file)) }

  describe '#call' do
    before do
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

      env[:domain_volumes] = []
      env[:domain_volumes].push({
        :device=>'vda',
        :bus=>'virtio',
        :cache=>'default',
        :absolute_path=>'/var/lib/libvirt/images/vagrant-test_default.img',
        :path=>"/test/box.img",
        :name=>'test_vagrant_box_image_1.1.1_0.img',
        :virtual_size=> ByteNumber.new(5),
        :pool=>'default',
      })
    end

    context 'connection => qemu:///system' do
      let(:domain_xml_file) { 'default_domain.xml' }

      before do
        allow(machine.provider_config).to receive(:qemu_use_session).and_return(false)
      end

      it 'should execute correctly' do
        expect(servers).to receive(:create).with(xml: domain_xml).and_return(machine)
        expect(volumes).to_not receive(:create) # additional disks only

        expect(subject.call(env)).to be_nil
      end

      context 'graphics autoport disabled' do
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.graphics_port = 5900
          libvirt.graphics_websocket = 5700
          EOF
        end

        it 'should emit the graphics port and websocket' do
          expect(servers).to receive(:create).and_return(machine)
          expect(volumes).to_not receive(:create) # additional disks only
          expect(ui).to receive(:info).with(' -- Graphics Port:     5900')
          expect(ui).to receive(:info).with(' -- Graphics Websocket: 5700')

          expect(subject.call(env)).to be_nil
        end
      end

      context 'with custom disk device setting' do
        let(:domain_xml_file) { 'custom_disk_settings.xml' }

        before do
          env[:domain_volumes][0][:device] = 'sda'
        end

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
          expect(volumes).to receive(:all).with(name: 'vagrant-test_default.img').and_return([domain_volume])
          expect(volumes).to receive(:all).with(name: 'vagrant-test_default_1.img').and_return([domain_volume_2])
          expect(domain_volume_2).to receive(:pool_name).and_return('default')

          env[:domain_volumes].push({
            :device=>'vdb',
            :bus=>'virtio',
            :cache=>'default',
            :absolute_path=>'/var/lib/libvirt/images/vagrant-test_default_1.img',
            :path=>"/test/box_1.img",
            :name=>"test_vagrant_box_image_1.1.1_1.img",
            :virtual_size=> ByteNumber.new(5),
            :pool=>'default',
          })
        end

        it 'should list multiple device entries' do
          expect(ui).to receive(:info).with(/ -- Image\(vda\):.*/)
          expect(ui).to receive(:info).with(/ -- Image\(vdb\):.*/)
          expect(servers).to receive(:create).with(xml: domain_xml).and_return(machine)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'with disk controller model virtio-scsi' do
        before do
          allow(machine.provider_config).to receive(:disk_controller_model).and_return('virtio-scsi')
          expect(volumes).to receive(:all).with(name: 'vagrant-test_default.img').and_return([domain_volume])

          env[:domain_volumes][0][:bus] = 'scsi'
        end

        it 'should add a virtio-scsi disk controller' do
          expect(ui).to receive(:info).with(/ -- Image\(vda\):.*/)
          expect(servers).to receive(:create) do |args|
            expect(args[:xml]).to match(/<controller type='scsi' model='virtio-scsi' index='0'\/>/)
          end.and_return(machine)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'launchSecurity' do
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.launchsecurity :type => 'sev', :cbitpos => 47, :reducedPhysBits => 1, :policy => "0x0003"
          EOF
        end

        it 'should emit the settings to the ui' do
          expect(ui).to receive(:info).with(/ -- Launch security:   type=sev, cbitpos=47, reducedPhysBits=1, policy=0x0003/)
          expect(servers).to receive(:create).and_return(machine)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'memtunes' do
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.memtune :type => 'hard_limit', :value => 250000
          libvirt.memtune :type => 'soft_limit', :value => 200000
          EOF
        end

        it 'should emit the settings to the ui' do
          expect(ui).to receive(:info).with(/ -- Memory Tuning:     hard_limit: unit='KiB', value: 250000/)
          expect(ui).to receive(:info).with(/ -- Memory Tuning:     soft_limit: unit='KiB', value: 200000/)
          expect(servers).to receive(:create).and_return(machine)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'sysinfo' do
        let(:domain_xml_file) { 'sysinfo.xml' }
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.sysinfo = {
            'bios': {
              'vendor': 'Test Vendor',
              'version': '',
            },
            'system': {
              'manufacturer': 'Test Manufacturer',
              'version': '0.1.0',
              'serial': '',
            },
            'base board': {
              'manufacturer': 'Test Manufacturer',
              'version': '',
            },
            'chassis': {
              'manufacturer': 'Test Manufacturer',
              'serial': 'AABBCCDDEE',
              'asset': '',
            },
            'oem strings': [
              'app1: string1',
              'app1: string2',
              'app2: string1',
              'app2: string2',
              '',
              '',
            ],
          }
          EOF
        end

        it 'should populate sysinfo as expected' do
          expect(servers).to receive(:create).with(xml: domain_xml).and_return(machine)

          expect(subject.call(env)).to be_nil
        end

        context 'with block of empty entries' do
          let(:domain_xml_file) { 'sysinfo_only_required.xml' }
          let(:vagrantfile_providerconfig) do
            <<-EOF
            libvirt.sysinfo = {
              'bios': {
                'vendor': 'Test Vendor',
              },
              'system': {
                'serial': '',
              },
            }
            EOF
          end

          it 'should skip outputting the surrounding tags' do
            expect(servers).to receive(:create).with(xml: domain_xml).and_return(machine)

            expect(subject.call(env)).to be_nil
          end
        end
      end
    end

    context 'connection => qemu:///session' do
      before do
        allow(machine.provider_config).to receive(:qemu_use_session).and_return(true)
      end

      it 'should execute correctly' do
        expect(servers).to receive(:create).and_return(machine)

        expect(subject.call(env)).to be_nil
      end
    end
  end
end
