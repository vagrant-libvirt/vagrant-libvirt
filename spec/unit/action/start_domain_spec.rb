# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/action/start_domain'
require 'vagrant-libvirt/util/unindent'

describe VagrantPlugins::ProviderLibvirt::Action::StartDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:servers) { double('servers') }

  let(:domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), test_file)) }
  let(:updated_domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), updated_test_file)) }

  before do
    allow(driver).to receive(:created?).and_return(true)
  end

  describe '#call' do
    let(:test_file) { 'default.xml' }

    before do
      allow(connection).to receive(:client).and_return(libvirt_client)
      allow(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)

      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)

      allow(logger).to receive(:debug)
      allow(logger).to receive(:info)
      allow(ui).to receive(:info)

      allow(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)

      allow(libvirt_domain).to receive(:max_memory).and_return(512*1024)
      allow(libvirt_domain).to receive(:num_vcpus).and_return(1)
    end

    it 'should execute without changing' do
      expect(ui).to_not receive(:warn)
      expect(libvirt_client).to_not receive(:define_domain_xml)
      expect(libvirt_domain).to receive(:autostart=)
      expect(domain).to receive(:start)

      expect(subject.call(env)).to be_nil
    end

    context 'when xml is formatted differently' do
      let(:test_file) { 'default_with_different_formatting.xml' }
      let(:updated_domain_xml) {
        new_xml = domain_xml.dup
        new_xml.gsub!(/<cpu .*<\/cpu>/m, '<cpu check="none" mode="host-passthrough"/>')
        new_xml
      }
      let(:vagrantfile_providerconfig) do
        <<-EOF
        libvirt.cpu_mode = "host-passthrough"
        EOF
      end

      it 'should correctly detect the domain was updated' do
        expect(ui).to_not receive(:warn)
        expect(libvirt_domain).to receive(:autostart=)
        expect(connection).to receive(:define_domain).and_return(libvirt_domain)
        expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
        expect(domain).to receive(:start)

        expect(subject.call(env)).to be_nil
      end
    end

    context 'when xml elements and attributes reordered' do
      let(:test_file) { 'existing.xml' }
      let(:updated_test_file) { 'existing_reordered.xml' }
      let(:vagrantfile_providerconfig) do
        <<-EOF
        libvirt.cpu_mode = "host-passthrough"
        EOF
      end

      it 'should correctly detect the domain was updated' do
        expect(ui).to_not receive(:warn)
        expect(libvirt_domain).to receive(:autostart=)
        expect(connection).to receive(:define_domain).and_return(libvirt_domain)
        expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
        expect(domain).to receive(:start)

        expect(subject.call(env)).to be_nil
      end
    end

    context 'when xml not applied' do
      let(:test_file) { 'default_with_different_formatting.xml' }
      let(:updated_domain_xml) {
        new_xml = domain_xml.dup
        new_xml.gsub!(/<cpu .*<\/cpu>/m, '<cpu mode="host-passthrough"/>')
        new_xml
      }
      let(:vagrantfile_providerconfig) do
        <<-EOF
        libvirt.cpu_mode = "host-passthrough"
        EOF
      end

      it 'should error and revert the update' do
        expect(ui).to receive(:warn).with(/\+  <cpu mode="host-passthrough" \/>.*Typically this means there is a bug in the XML being sent, please log an issue/m)
        expect(connection).to receive(:define_domain).and_return(libvirt_domain)
        #expect(connection).to receive(:define_domain).with(domain_xml) # undo
        expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
        #expect(domain).to_not receive(:start)

        #expect { subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::UpdateServerError)
        expect(libvirt_domain).to receive(:autostart=)
        expect(domain).to receive(:start)
        expect(subject.call(env)).to be_nil
      end
    end

    context 'when any setting changed' do
      let(:vagrantfile_providerconfig) do
        <<-EOF
        libvirt.cpus = 2
        EOF
      end

      let(:updated_domain_xml) {
        new_xml = domain_xml.dup
        new_xml['<vcpu>1</vcpu>'] = '<vcpu>2</vcpu>'
        new_xml
      }

      it 'should update the domain' do
        expect(ui).to_not receive(:warn)
        expect(libvirt_domain).to receive(:autostart=)
        expect(connection).to receive(:define_domain).and_return(libvirt_domain)
        expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
        expect(domain).to receive(:start)

        expect(subject.call(env)).to be_nil
      end

      context 'when there is an error during update' do
        it 'should skip attempting to start' do
          expect(ui).to receive(:error)
          expect(connection).to receive(:define_domain).and_raise(::Libvirt::Error)

          expect { subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::VagrantLibvirtError)
        end
      end

      context 'when there is an interrupt' do
        it 'should skip attempting to start' do
          expect(connection).to receive(:define_domain).and_raise(Interrupt)

          expect { subject.call(env) }.to raise_error(Interrupt)
        end
      end
    end

    context 'interface' do
      let(:test_file) { 'existing_with_iommu.xml' }
      let(:updated_domain_xml) {
        new_xml = domain_xml.dup
        new_xml.sub!(
          /<model type='virtio'\/>\s+<driver iommu='on'\/>/m,
          <<-EOF
          <model type='e1000'/>
          EOF
        )
        new_xml
      }
      let(:vagrantfile_providerconfig) {
        <<-EOF
        libvirt.management_network_model_type = 'e1000'
        EOF
      }

      it 'should remove iommu if not interface model not virtio' do
        expect(ui).to_not receive(:warn)
        expect(connection).to receive(:define_domain).and_return(libvirt_domain)
        expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
        expect(libvirt_domain).to receive(:autostart=)
        expect(domain).to receive(:start)

        expect(subject.call(env)).to be_nil
      end

      context 'iommu mismatch' do
        let(:updated_domain_xml) {
          new_xml = domain_xml.dup
          new_xml.sub!(/(<model type='virtio'\/>\s+)<driver iommu='on'\/>/m) { |_|
            match = Regexp.last_match

            "#{match[1]}<driver iommu='off'/>"
          }
          new_xml
        }
        let(:vagrantfile_providerconfig) {
          <<-EOF
          libvirt.management_network_driver_iommu = false
          EOF
        }


        it 'should update iommu to off' do
          expect(ui).to_not receive(:warn)
          expect(connection).to receive(:define_domain).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'with additional interface' do
        let(:test_file) { 'existing_with_two_interfaces_iommu.xml' }
        let(:adapters) {
          [
            {:iface_type => :private_network, :model_type => "e1000", :network_name => "vagrant-libvirt", :driver_iommu => false},
            {:iface_type => :private_network, :model_type => "virtio", :network_name => "vagrant-libvirt-1", :driver_iommu => true},
          ]
        }
        before do
          allow(subject).to receive(:network_interfaces).and_return(adapters)
        end

        it 'should only update the management interface' do
          expect(updated_domain_xml).to match(/<source network='vagrant-libvirt'\/>\s+<model type='e1000'\/>/m)
          expect(updated_domain_xml).to match(/<source network='private'\/>\s+<model type='virtio'\/>/m)

          expect(ui).to_not receive(:warn)
          expect(connection).to receive(:define_domain).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end

        context 'with more adapters configured than attached' do
          let(:adapters) {
            [
              {:iface_type => :private_network, :model_type => "e1000", :network_name => "vagrant-libvirt", :driver_iommu => false},
              {:iface_type => :private_network, :model_type => "virtio", :network_name => "vagrant-libvirt-1", :driver_iommu => true},
              {:iface_type => :private_network, :model_type => "virtio", :network_name => "vagrant-libvirt-2", :driver_iommu => true},
            ]
          }

          it 'should update and trigger a warning about mismatched adapters' do
            expect(ui).to receive(:warn).with(/number of network adapters in current config \(3\) is different to attached interfaces \(2\)/)
            expect(connection).to receive(:define_domain).and_return(libvirt_domain)
            expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
            expect(libvirt_domain).to receive(:autostart=)
            expect(domain).to receive(:start)

            expect(subject.call(env)).to be_nil
          end
        end
      end
    end

    context 'cpu' do
      let(:test_file) { 'existing.xml' }
      let(:updated_domain_xml) {
        new_xml = domain_xml.dup
        new_xml.gsub!(
          /<cpu .*\/>/,
          <<-EOF
          <cpu check='partial' mode='custom'>
            <model fallback='allow'>Haswell</model>
            <feature name='vmx' policy='optional'/>
            <feature name='svm' policy='optional'/>
          </cpu>
          EOF
        )
        new_xml
      }
      let(:vagrantfile_providerconfig) {
        <<-EOF
        libvirt.cpu_mode = 'custom'
        libvirt.cpu_model = 'Haswell'
        libvirt.nested = true
        EOF
      }

      it 'should set cpu related settings when changed' do
        expect(ui).to_not receive(:warn)
        expect(connection).to receive(:define_domain).and_return(libvirt_domain)
        expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
        expect(libvirt_domain).to receive(:autostart=)
        expect(domain).to receive(:start)

        expect(subject.call(env)).to be_nil
      end

      let(:domain_xml_no_cpu) {
        new_xml = domain_xml.dup
        new_xml.gsub!(/<cpu .*\/>/, '')
        new_xml
      }
      let(:updated_domain_xml_new_cpu) {
        new_xml = domain_xml.dup
        new_xml.gsub!(
          /<cpu .*\/>/,
          <<-EOF
          <cpu mode='custom'>
            <model fallback='allow'>Haswell</model>
            <feature name='vmx' policy='optional'/>
            <feature name='svm' policy='optional'/>
          </cpu>
          EOF
        )
        new_xml
      }

      it 'should add cpu settings if not already present' do
        expect(ui).to_not receive(:warn)
        expect(connection).to receive(:define_domain).and_return(libvirt_domain)
        expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml_no_cpu, updated_domain_xml_new_cpu)
        expect(libvirt_domain).to receive(:autostart=)
        expect(domain).to receive(:start)

        expect(subject.call(env)).to be_nil
      end
    end

    context 'launchSecurity' do
      let(:updated_domain_xml_new_launch_security) {
        new_xml = domain_xml.dup
        new_xml.gsub!(
          /<\/devices>/,
          <<-EOF.unindent.rstrip
          </devices>
            <launchSecurity type='sev'>
              <cbitpos>47</cbitpos>
              <reducedPhysBits>1</reducedPhysBits>
              <policy>0x0003</policy>
            </launchSecurity>
          EOF
        )
        new_xml
      }

      it 'should create if not already set' do
        machine.provider_config.launchsecurity_data = {:type => 'sev', :cbitpos => 47, :reducedPhysBits => 1, :policy => "0x0003"}

        expect(ui).to_not receive(:warn)
        expect(connection).to receive(:define_domain).and_return(libvirt_domain)
        expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml_new_launch_security)
        expect(libvirt_domain).to receive(:autostart=)
        expect(domain).to receive(:start)

        expect(subject.call(env)).to be_nil
      end

      context 'already exists' do
        let(:domain_xml_launch_security) { updated_domain_xml_new_launch_security }
        let(:updated_domain_xml_launch_security) {
          new_xml = domain_xml_launch_security.dup
          new_xml.gsub!(/<cbitpos>47/, '<cbitpos>48')
          new_xml.gsub!(/<reducedPhysBits>1/, '<reducedPhysBits>2')
          new_xml.gsub!(/<policy>0x0003/, '<policy>0x0004')
          new_xml
        }


        it 'should update all settings' do
          machine.provider_config.launchsecurity_data = {:type => 'sev', :cbitpos => 48, :reducedPhysBits => 2, :policy => "0x0004"}

          expect(ui).to_not receive(:warn)
          expect(connection).to receive(:define_domain).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml_launch_security, updated_domain_xml_launch_security)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end

        it 'should remove if disabled' do
          machine.provider_config.launchsecurity_data = nil

          expect(ui).to_not receive(:warn)
          expect(connection).to receive(:define_domain).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml_launch_security, domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end

        context 'with controllers' do
          # makes domain_xml contain 2 controllers and memballoon
          # which should mean that launchsecurity element exists, but without
          # iommu set on controllers
          let(:test_file) { 'existing.xml' }
          let(:updated_domain_xml_launch_security_controllers) {
            new_xml = updated_domain_xml_new_launch_security.dup
            new_xml.gsub!(
              /<controller type='pci' index='0' model='pci-root'\/>/,
              "<controller type='pci' index='0' model='pci-root'><driver iommu='on'/></controller>",
            )
            new_xml.gsub!(
              /(<address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x2'\/>)/,
              '\1<driver iommu="on"/>',
            )
            # memballoon
            new_xml.gsub!(
              /(<address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'\/>)/,
              '\1<driver iommu="on"/>',
            )
            new_xml
          }

          it 'should set driver iommu on all controllers' do
            machine.provider_config.launchsecurity_data = {:type => 'sev', :cbitpos => 47, :reducedPhysBits => 1, :policy => "0x0003"}

            expect(ui).to_not receive(:warn)
            expect(connection).to receive(:define_domain).and_return(libvirt_domain)
            expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml_launch_security, updated_domain_xml_launch_security_controllers)
            expect(libvirt_domain).to receive(:autostart=)
            expect(domain).to receive(:start)

            expect(subject.call(env)).to be_nil
          end
        end
      end
    end

    context 'graphics' do
      context 'autoport not disabled' do
        let(:test_file) { 'existing.xml' }
        let(:launched_domain_xml) {
          new_xml = domain_xml.dup
          new_xml.gsub!(/graphics type='vnc' port='-1'/m, "graphics type='vnc' port='5900'")
          new_xml
        }

        it 'should retrieve the port from XML' do
          expect(ui).to_not receive(:warn)
          expect(connection).to_not receive(:define_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, launched_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)
          expect(ui).to receive(:info).with(' -- Graphics Port:      5900')

          expect(subject.call(env)).to be_nil
        end
      end

      [
        [
          'when port explicitly set, should set autoport=no',
          proc { |config|
            config.graphics_port = 5901
          },
          "<graphics autoport='yes' keymap='en-us' listen='127.0.0.1' port='-1' type='vnc' websocket='-1'/>",
          "<graphics autoport='no' keymap='en-us' listen='127.0.0.1' port='5901' type='vnc' websocket='-1'/>",
        ],
        [
          'when port updated, should set autoport=no and update port',
          proc { |config|
            config.graphics_port = 5902
          },
          "<graphics autoport='no' keymap='en-us' listen='127.0.0.1' port='5901' type='vnc' websocket='-1'/>",
          "<graphics autoport='no' keymap='en-us' listen='127.0.0.1' port='5902' type='vnc' websocket='-1'/>",
        ],
        [
          'when autoport set and no port, should set autoport=yes and update port to -1',
          proc { |config|
            config.graphics_autoport = 'yes'
          },
          "<graphics autoport='no' keymap='en-us' listen='127.0.0.1' port='5901' type='vnc' websocket='-1'/>",
          "<graphics autoport='yes' keymap='en-us' listen='127.0.0.1' port='-1' type='vnc' websocket='-1'/>",
        ],
      ].each do |description, config_proc, graphics_xml_start, graphics_xml_output|
        it "#{description}" do
          config_proc.call(machine.provider_config)

          initial_domain_xml = domain_xml.gsub(/<graphics .*\/>/, graphics_xml_start)
          updated_domain_xml = domain_xml.gsub(/<graphics .*\/>/, graphics_xml_output)

          expect(ui).to_not receive(:warn)
          expect(connection).to receive(:define_domain).with(match(graphics_xml_output)).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(initial_domain_xml, updated_domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'nvram' do
      context 'when being added to existing' do
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.loader = "/path/to/loader/file"
          libvirt.nvram = "/path/to/nvram/file"
          EOF
        end
        let(:test_file) { 'existing.xml' }
        let(:updated_test_file) { 'existing_added_nvram.xml' }

        it 'should add the nvram element' do
          expect(ui).to_not receive(:warn)
          expect(connection).to receive(:define_domain).with(updated_domain_xml).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'when it was already in use' do
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.loader = "/path/to/loader/file"
          libvirt.nvram = "/path/to/nvram/file1"
          EOF
        end
        let(:test_file) { 'nvram_domain.xml' }
        let(:updated_test_file) { 'nvram_domain_other_setting.xml' }

        it 'should keep the XML element' do
          expect(ui).to_not receive(:warn)
          expect(connection).to receive(:define_domain).with(updated_domain_xml).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end

        context 'when it is being disabled' do
          let(:vagrantfile_providerconfig) { }
          let(:updated_test_file) { 'nvram_domain_removed.xml' }

          it 'should delete the XML element' do
            expect(ui).to_not receive(:warn)
            expect(connection).to receive(:define_domain).with(updated_domain_xml).and_return(libvirt_domain)
            expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
            expect(libvirt_domain).to receive(:autostart=)
            expect(domain).to receive(:start)

            expect(subject.call(env)).to be_nil
          end
        end
      end
    end

    context 'tpm' do
      context 'passthrough tpm added' do
        let(:updated_test_file) { 'default_added_tpm_path.xml' }
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.tpm_path = '/dev/tpm0'
          libvirt.tpm_type = 'passthrough'
          libvirt.tpm_model = 'tpm-tis'
          EOF
        end

        it 'should modify the domain tpm_path' do
          expect(ui).to_not receive(:warn)
          expect(logger).to receive(:debug).with('tpm config changed')
          expect(connection).to receive(:define_domain).with(updated_domain_xml).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'emulated tpm added' do
        let(:updated_test_file) { 'default_added_tpm_version.xml' }
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.tpm_type = 'emulator'
          libvirt.tpm_model = 'tpm-crb'
          libvirt.tpm_version = '2.0'
          EOF
        end

        it 'should modify the domain tpm_path' do
          expect(ui).to_not receive(:warn)
          expect(logger).to receive(:debug).with('tpm config changed')
          expect(connection).to receive(:define_domain).with(updated_domain_xml).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'same passthrough tpm config' do
        let(:test_file) { 'default_added_tpm_path.xml' }
        let(:updated_test_file) { 'default_added_tpm_path.xml' }
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.tpm_path = '/dev/tpm0'
          libvirt.tpm_type = 'passthrough'
          libvirt.tpm_model = 'tpm-tis'
          EOF
        end

        it 'should execute without changing' do
          expect(ui).to_not receive(:warn)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'same emulated tpm config' do
        let(:test_file) { 'default_added_tpm_version.xml' }
        let(:updated_test_file) { 'default_added_tpm_version.xml' }
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.tpm_type = 'emulator'
          libvirt.tpm_model = 'tpm-crb'
          libvirt.tpm_version = '2.0'
          EOF
        end

        it 'should execute without changing' do
          expect(ui).to_not receive(:warn)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'change from passthrough to emulated' do
        let(:test_file) { 'default_added_tpm_path.xml' }
        let(:updated_test_file) { 'default_added_tpm_version.xml' }
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.tpm_type = 'emulator'
          libvirt.tpm_model = 'tpm-crb'
          libvirt.tpm_version = '2.0'
          EOF
        end

        it 'should modify the domain' do
          expect(ui).to_not receive(:warn)
          expect(logger).to receive(:debug).with('tpm config changed')
          expect(connection).to receive(:define_domain).with(updated_domain_xml).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'clock_timers' do
      let(:test_file) { 'clock_timer_rtc.xml' }

      context 'timers unchanged' do
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.clock_timer(:name => "rtc")
          EOF
        end

        it 'should not modify the domain' do
          expect(ui).to_not receive(:warn)
          expect(logger).to_not receive(:debug).with('clock timers config changed')
          expect(connection).to_not receive(:define_domain)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'timers added' do
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.clock_timer(:name => "rtc")
          libvirt.clock_timer(:name => "tsc")
          EOF
        end

        let(:updated_test_file) { 'clock_timer_rtc_tsc.xml' }

        it 'should modify the domain' do
          expect(ui).to_not receive(:warn)
          expect(logger).to receive(:debug).with('clock timers config changed')
          expect(connection).to receive(:define_domain).with(match(/<clock offset='utc'>\s*<timer name='rtc'\/>\s*<timer name='tsc'\/>\s*<\/clock>/)).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'timers removed' do
        let(:updated_test_file) { 'clock_timer_removed.xml' }

        it 'should modify the domain' do
          expect(ui).to_not receive(:warn)
          expect(logger).to receive(:debug).with('clock timers config changed')
          expect(connection).to receive(:define_domain).with(match(/<clock offset='utc'>\s*<\/clock>/)).and_return(libvirt_domain)
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml, updated_domain_xml)
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end
    end
  end
end
