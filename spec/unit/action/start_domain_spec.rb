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

  let(:libvirt_domain) { double('libvirt_domain') }
  let(:libvirt_client) { double('libvirt_client') }
  let(:servers) { double('servers') }

  let(:domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), test_file)) }
  let(:updated_domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), updated_test_file)) }

  describe '#call' do
    let(:test_file) { 'default.xml' }

    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:client).and_return(libvirt_client)
      allow(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)

      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)

      allow(logger).to receive(:debug)
      expect(logger).to receive(:info)
      expect(ui).to_not receive(:error)

      allow(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)

      allow(libvirt_domain).to receive(:max_memory).and_return(512*1024)
      allow(libvirt_domain).to receive(:num_vcpus).and_return(1)
    end

    it 'should execute without changing' do
      allow(libvirt_domain).to receive(:undefine)
      expect(logger).to_not receive(:debug)
      expect(libvirt_domain).to receive(:autostart=)
      expect(domain).to receive(:start)

      expect(subject.call(env)).to be_nil
    end

    context 'when previously running default config' do
      let(:test_file) { 'existing.xml' }

      it 'should execute without changing' do
        allow(libvirt_domain).to receive(:undefine)
        expect(libvirt_domain).to receive(:autostart=)
        expect(domain).to receive(:start)

        expect(subject.call(env)).to be_nil
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
          expect(libvirt_domain).to receive(:undefine)
          expect(logger).to receive(:debug).with('tpm config changed')
          expect(servers).to receive(:create).with(xml: updated_domain_xml)
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
          expect(libvirt_domain).to receive(:undefine)
          expect(logger).to receive(:debug).with('tpm config changed')
          expect(servers).to receive(:create).with(xml: updated_domain_xml)
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
          expect(libvirt_domain).to receive(:undefine)
          expect(logger).to receive(:debug).with('tpm config changed')
          expect(servers).to receive(:create).with(xml: updated_domain_xml)
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
          expect(logger).to_not receive(:debug).with('clock timers config changed')
          expect(servers).to_not receive(:create)
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

        it 'should modify the domain' do
          expect(libvirt_domain).to receive(:undefine)
          expect(logger).to receive(:debug).with('clock timers config changed')
          expect(servers).to receive(:create).with(xml: match(/<clock offset='utc'>\s*<timer name='rtc'\/>\s*<timer name='tsc'\/>\s*<\/clock>/))
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'timers removed' do
        it 'should modify the domain' do
          expect(libvirt_domain).to receive(:undefine)
          expect(logger).to receive(:debug).with('clock timers config changed')
          expect(servers).to receive(:create).with(xml: match(/<clock offset='utc'>\s*<\/clock>/))
          expect(libvirt_domain).to receive(:autostart=)
          expect(domain).to receive(:start)

          expect(subject.call(env)).to be_nil
        end
      end
    end
  end
end
