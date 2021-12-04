# frozen_string_literal: true

require 'vagrant-libvirt/action/wait_till_up'
require 'vagrant-libvirt/errors'

require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'

describe VagrantPlugins::ProviderLibvirt::Action::WaitTillUp do
  subject { described_class.new(app, env) }

  include_context 'vagrant-unit'
  include_context 'libvirt'
  include_context 'unit'

  let (:driver) { VagrantPlugins::ProviderLibvirt::Driver.new env[:machine] }

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Provider).to receive(:driver)
        .and_return(driver)
      allow(driver).to receive(:get_domain).and_return(domain)
      allow(driver).to receive(:state).and_return(:running)
      # return some information for domain when needed
      allow(domain).to receive(:mac).and_return('9C:D5:53:F1:5A:E7')
    end

    context 'when machine does not exist' do
      before do
        allow(driver).to receive(:get_domain).and_return(nil)
      end

      it 'raises exception' do
        expect(app).to_not receive(:call)
        expect { subject.call(env) }.to raise_error(::VagrantPlugins::ProviderLibvirt::Errors::NoDomainError,
                                                    /No domain found. Domain dummy-vagrant_dummy not found/)
      end
    end

    context 'when machine is booting' do
      context 'if interrupted looking for IP' do
        before do
          env[:interrupted] = true
        end
        it 'should exit' do
          expect(app).to_not receive(:call)
          expect(ui).to receive(:info).with('Waiting for domain to get an IP address...')
          expect(logger).to receive(:debug).with(/Searching for IP for MAC address: .*/)
          expect(subject.call(env)).to be_nil
        end
      end

      context 'multiple timeouts waiting for IP' do
        before do
          allow(env).to receive(:[]).and_call_original
          allow(env).to receive(:[]).with(:interrupted).and_return(false)
          allow(logger).to receive(:debug)
          allow(logger).to receive(:info)
        end

        it 'should abort after hitting limit' do
          expect(domain).to receive(:wait_for).at_least(300).times.and_raise(::Fog::Errors::TimeoutError)
          expect(app).to_not receive(:call)
          expect(ui).to receive(:info).with('Waiting for domain to get an IP address...')
          expect(ui).to_not receive(:info).with('Waiting for SSH to become available...')
          expect {subject.call(env) }.to raise_error(::Fog::Errors::TimeoutError)
        end
      end
    end

    context 'when machine boots and ip available' do
      before do
        allow(domain).to receive(:wait_for).and_return(true)
        allow(env).to receive(:[]).and_call_original
        allow(env).to receive(:[]).with(:interrupted).and_return(false)
        allow(driver).to receive(:get_domain_ipaddress).and_return('192.168.121.2')
      end
      it 'should call the next hook' do
        expect(app).to receive(:call)
        expect(ui).to receive(:info).with('Waiting for domain to get an IP address...')
        expect(logger).to receive(:debug).with(/Searching for IP for MAC address: .*/)
        expect(logger).to receive(:info).with('Got IP address 192.168.121.2')
        expect(logger).to receive(:info).with(/Time for getting IP: .*/)
        expect(subject.call(env)).to be_nil
      end
    end
  end
end
