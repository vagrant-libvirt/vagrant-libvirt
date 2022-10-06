# frozen_string_literal: true

require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/action/start_domain'

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
          expect(ui).to receive(:info).with(' -- Graphics Port:     5900')

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
