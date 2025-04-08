# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/config'
require 'vagrant-libvirt/util/erb_template'

describe 'templates/domain' do
  include_context 'unit'

  class DomainTemplateHelper < VagrantPlugins::ProviderLibvirt::Config
    include VagrantPlugins::ProviderLibvirt::Util::ErbTemplate

    attr_accessor :domain_volumes

    def initialize
      super
      @domain_volumes = []
      @sysinfo_blocks = {
        'bios' => {:section => "BIOS", :xml => "bios"},
        'system' => {:section => "System", :xml => "system"},
        'base board' => {:section => "Base Board", :xml => "baseBoard"},
        'chassis' => {:section => "Chassis", :xml => "chassis"},
        'oem strings' => {:section => "OEM Strings", :xml => "oemStrings"},
      }
    end

    def finalize!
      super

      disks.each do |disk|
        disk[:absolute_path] = '/var/lib/libvirt/images/' + disk[:path]
      end
    end
  end

  def resolve
    # resolving is now done during create domain, so need to recreate
    # the same behaviour before calling the template until that
    # is separated out from create domain.
    resolver = ::VagrantPlugins::ProviderLibvirt::Util::DiskDeviceResolver.new(prefix=domain.disk_device[0..1])
    resolver.resolve!(domain.domain_volumes.dup.each { |volume| volume[:device] = volume[:dev] })
    resolver.resolve!(domain.disks)
  end

  let(:domain) { DomainTemplateHelper.new }
  let(:xml_expected) { File.read(File.join(File.dirname(__FILE__), test_file)) }

  context 'when only defaults used' do
    let(:test_file) { 'domain_defaults.xml' }
    it 'renders template' do
      domain.finalize!
      expect(domain.to_xml('domain')).to eq xml_expected
    end
  end

  context 'when all settings enabled' do
    before do
      domain.title = 'title'
      domain.description = 'description'
      domain.instance_variable_set('@domain_type', 'kvm')
      domain.cpu_mode = 'custom'
      domain.cpu_feature(name: 'AAA', policy: 'required')
      domain.hyperv_feature(name: 'BBB', state: 'on')
      domain.clock_adjustment = -(365 * 24 * 60 * 60)
      domain.clock_basis = 'localtime'
      domain.clock_timer(name: 't1')
      domain.clock_timer(name: 't2', track: 'b', tickpolicy: 'c', frequency: 'd', mode: 'e',  present: 'yes')
      domain.hyperv_feature(name: 'spinlocks', state: 'on', retries: '4096')
      domain.cputopology(sockets: '1', cores: '3', threads: '2')
      domain.memtune(type: 'hard_limit', value: '250000')
      domain.memtune(type: 'soft_limit', value: '200000')
      domain.cpuaffinitiy(0 => '0')
      domain.machine_type = 'pc-compatible'
      domain.machine_arch = 'x86_64'
      domain.loader = '/efi/loader'
      domain.boot('network')
      domain.boot('cdrom')
      domain.boot('hd')
      domain.emulator_path = '/usr/bin/kvm-spice'
      domain.instance_variable_set('@domain_volume_cache', 'deprecated')
      domain.disk_bus = 'ide'
      domain.disk_device = 'vda'
      domain.disk_address_type = 'virtio-mmio'
      domain.disk_driver(:cache => 'unsafe', :io => 'threads', :copy_on_read => 'on', :discard => 'unmap', :detect_zeroes => 'on')
      domain.storage(:file, path: 'test-disk1.qcow2')
      domain.storage(:file, path: 'test-disk2.qcow2', io: 'threads', copy_on_read: 'on', discard: 'unmap', detect_zeroes: 'on')
      domain.storage(:file, path: 'test-disk3.qcow2', address_type: 'pci')
      domain.storage(:file, device: :floppy)
      domain.storage(:file, device: :cdrom)
      domain.storage(:file, device: :cdrom)
      domain.channel(type: 'unix',
                     target_name: 'org.qemu.guest_agent.0',
                     target_type: 'virtio')
      domain.channel(type: 'spicevmc',
                     target_name: 'com.redhat.spice.0',
                     target_type: 'virtio')
      domain.channel(type: 'unix',
                     target_type: 'guestfwd',
                     target_address: '192.0.2.42',
                     target_port: '4242',
                     source_path: '/tmp/foo')
      domain.random(model: 'random')
      domain.serial(:type => 'file', :source => {:path => '/var/log/vm_consoles/machine.log'})
      domain.pci(bus: '0x06', slot: '0x12', function: '0x5')
      domain.pci(domain: '0x0001', bus: '0x03', slot: '0x00', function: '0x0')
      domain.pci(domain: '0x0002', bus: '0x04', slot: '0x00', function: '0x0', guest_domain: '0x0000', guest_bus: '0x01', guest_slot: '0x01', guest_function: '0x0')
      domain.usb_controller(model: 'nec-xhci', ports: '4')
      domain.usb(bus: '1', device: '2', vendor: '0x1234', product: '0xabcd')
      domain.redirdev(type: 'tcp', host: 'localhost', port: '4000')
      domain.redirfilter(class: '0x0b', vendor: '0x08e6',
                         product: '0x3437', version: '2.00', allow: 'yes')
      domain.watchdog(model: 'i6300esb', action: 'reset')
      domain.smartcard(mode: 'passthrough')
      domain.tpm_path = '/dev/tpm0'

      domain.sysinfo = {
        'system' => {
          'serial' => 'AAAAAAAA',
        },
        'oem strings' => [
          'AAAAAAAA',
        ],
      }

      domain.qemuargs(value: '-device')
      domain.qemuargs(value: 'dummy-device')

      domain.qemuenv(QEMU_AUDIO_DRV: 'pa')
      domain.qemuenv(QEMU_AUDIO_TIMER_PERIOD: '150')
      domain.qemuenv(QEMU_PA_SAMPLES: '1024')
      domain.qemuenv(QEMU_PA_SERVER: '/run/user/1000/pulse/native')

      domain.shares = '1024'
      domain.cpuset = '1-4,^3,6'
      domain.nodeset = '1-4,^3,6'

      domain.video_accel3d = true
    end
    let(:test_file) { 'domain_all_settings.xml' }
    it 'renders template' do
      domain.finalize!

      domain.domain_volumes.push({
        :cache => 'unsafe',
        :bus => domain.disk_bus,
        :absolute_path => '/var/lib/libvirt/images/test.qcow2',
        :address_type => 'virtio-mmio',
      })
      domain.domain_volumes.push({
        :cache => 'unsafe',
        :bus => domain.disk_bus,
        :absolute_path => '/var/lib/libvirt/images/test2.qcow2',
        :address_type => 'virtio-mmio',
      })
      resolve

      expect(domain.to_xml('domain')).to eq xml_expected
    end
  end

  context 'when cpu mode is set' do
    context 'to host-passthrough' do
      before do
        domain.cpu_mode = 'host-passthrough'
        domain.cpu_model = 'SandyBridge'
        domain.cputopology :sockets => '1', :cores => '2', :threads => '1'
        domain.nested = true
      end
      let(:test_file) { 'domain_cpu_mode_passthrough.xml' }
      it 'should allow features and topology and ignore model' do
        domain.finalize!
        expect(domain.to_xml('domain')).to eq xml_expected
      end
    end

    context 'to custom and model is set' do
      before do
        domain.cpu_mode = 'custom'
        domain.cpu_model = 'SandyBridge'
      end
      let(:test_file) { 'domain_custom_cpu_model.xml' }
      it 'renders template' do
        domain.finalize!
        expect(domain.to_xml('domain')).to eq xml_expected
      end
    end
  end

  context 'when tpm 2.0 device is specified' do
    before do
      domain.tpm_version = '2.0'
      domain.tpm_type = 'emulator'
      domain.tpm_model = 'tpm-crb'
    end
    let(:test_file) { 'tpm/version_2.0.xml' }
    it 'renders template' do
      domain.finalize!
      expect(domain.to_xml('domain')).to eq xml_expected
    end
  end

  context 'when tpm 1.2 device is implicitly used' do
    before do
      domain.tpm_path = '/dev/tpm0'
    end
    let(:test_file) { 'tpm/version_1.2.xml' }
    it 'renders template' do
      domain.finalize!
      expect(domain.to_xml('domain')).to eq xml_expected
    end
  end

  context 'memballoon' do
    context 'default' do
      it 'renders without specifying the xml tag' do
        domain.finalize!

        expect(domain.to_xml('domain')).to_not match(/memballoon/)
      end
    end

    context 'memballoon enabled' do
      before do
        domain.memballoon_enabled = true
      end

      it 'renders with memballoon element' do
        domain.finalize!

        expect(domain.to_xml('domain')).to match(/<memballoon model='virtio'>/)
        expect(domain.to_xml('domain')).to match(/<address type='pci' domain='0x0000' bus='0x00' slot='0x0f' function='0x0'\/>/)
      end

      context 'all settings specified' do
        before do
          domain.memballoon_model = "virtio-non-transitional"
          domain.memballoon_pci_bus = "0x01"
          domain.memballoon_pci_slot = "0x05"
        end

        it 'renders with specified values' do
          domain.finalize!

          expect(domain.to_xml('domain')).to match(/<memballoon model='virtio-non-transitional'>/)
          expect(domain.to_xml('domain')).to match(/<address type='pci' domain='0x0000' bus='0x01' slot='0x05' function='0x0'\/>/)
        end
      end
    end

    context 'memballoon disabled' do
      before do
        domain.memballoon_enabled = false
      end

      it 'renders the memballoon element with model none' do
        domain.finalize!

        expect(domain.to_xml('domain')).to match(/<memballoon model='none'\/>/)
      end
    end
  end

  context 'scsi controller' do
    context 'when disk device suggests scsi' do
      let(:test_file) { 'domain_scsi_device_storage.xml' }

      before do
        domain.disk_device = 'sda'
      end

      it 'renders scsi controller in template' do
        domain.finalize!
        domain.domain_volumes.push({
          :cache => 'unsafe',
          :bus => domain.disk_bus,
          :absolute_path => '/var/lib/libvirt/images/test.qcow2'
        })

        resolve
        expect(domain.to_xml('domain')).to eq xml_expected
      end
    end

    context 'when disk bus is scsi' do
      let(:test_file) { 'domain_scsi_bus_storage.xml' }

      before do
        domain.disk_bus = 'scsi'
      end

      it 'renders scsi controller in template based on bus' do
        domain.finalize!
        domain.domain_volumes.push({
          :dev => 'vda',
          :cache => 'unsafe',
          :bus => domain.disk_bus,
          :absolute_path => '/var/lib/libvirt/images/test.qcow2'
        })
        resolve
        expect(domain.to_xml('domain')).to eq xml_expected
      end
    end

    context 'when enough scsi disks are added' do
      let(:test_file) { 'domain_scsi_multiple_controllers_storage.xml' }

      before do
        domain.disk_bus = 'scsi'
        domain.disk_controller_model = 'virtio-scsi'
      end

      it 'should render with multiple scsi controllers' do
        domain.finalize!
        for idx in 1..15 do
          domain.domain_volumes.push({
            :cache => 'unsafe',
            :bus => domain.disk_bus,
            :absolute_path => "/var/lib/libvirt/images/test-#{idx}.img"
          })
        end
        resolve
        expect(domain.to_xml('domain')).to eq xml_expected
      end
    end
  end
end
