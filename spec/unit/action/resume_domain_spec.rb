# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/action/resume_domain'


describe VagrantPlugins::ProviderLibvirt::Action::ResumeDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:driver) { instance_double(::VagrantPlugins::ProviderLibvirt::Driver) }
  let(:libvirt_domain) { instance_double(::Libvirt::Domain) }
  let(:libvirt_client) { instance_double(::Libvirt::Connect) }
  let(:servers) { double('servers') }
  let(:state) { instance_double(::Vagrant::MachineState) }

  before do
    allow(machine.provider).to receive('driver').and_return(driver)
    allow(driver).to receive(:connection).and_return(connection)
  end

  describe '#call' do
    before do
      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)
      allow(connection).to receive(:client).and_return(libvirt_client)
      allow(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)

      allow(machine).to receive(:state).and_return(state)

      expect(ui).to receive(:info).with(/Resuming domain/)
    end

    it 'should resume by default' do
      expect(state).to receive(:id).and_return(:paused)
      expect(domain).to receive(:resume)
      expect(logger).to receive(:info).with('Machine dummy-vagrant_dummy is resumed.')

      expect(subject.call(env)).to be_nil
    end

    context 'when in pmsuspend' do
      it 'should wakeup the domain' do
        expect(state).to receive(:id).and_return(:pmsuspended)
        expect(libvirt_domain).to receive(:pmwakeup)
        expect(logger).to receive(:info).with('Machine dummy-vagrant_dummy is resumed.')

        expect(subject.call(env)).to be_nil
      end
    end

    context 'when suspend_mode is managedsave' do
      it 'should start the domain' do
        machine.provider_config.suspend_mode = 'managedsave'
        expect(state).to receive(:id).and_return(:paused)
        expect(domain).to receive(:start)
        expect(logger).to receive(:info).with('Machine dummy-vagrant_dummy is resumed.')

        expect(subject.call(env)).to be_nil
      end
    end
  end
end
