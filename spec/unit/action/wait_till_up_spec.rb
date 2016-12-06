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

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:get_domain).and_return(domain)
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver).to receive(:state)
        .and_return(:running)
    end

    context 'when machine does not exist' do
      before do
        allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
          .to receive(:get_domain).and_return(nil)
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
          expect(subject.call(env)).to be_nil
        end
      end

      context 'if interrupted waiting for SSH' do
        before do
          allow(domain).to receive(:wait_for).and_return(true)
          allow(env).to receive(:[]).and_call_original
          allow(env).to receive(:[]).with(:interrupted).and_return(false, true, true)
          allow(env).to receive(:[]).with(:ip_address).and_return('192.168.121.2')
        end
        it 'should exit after getting IP' do
          expect(app).to_not receive(:call)
          expect(ui).to receive(:info).with('Waiting for domain to get an IP address...')
          expect(ui).to receive(:info).with('Waiting for SSH to become available...')
          logger = subject.instance_variable_get(:@logger)
          expect(logger).to receive(:debug).with(/Searching for IP for MAC address: .*/)
          expect(logger).to receive(:info).with('Got IP address 192.168.121.2')
          expect(logger).to receive(:info).with(/Time for getting IP: .*/)
          expect(env[:machine].communicate).to_not receive(:ready?)
          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'when machine boots and ssh available' do
      before do
        allow(domain).to receive(:wait_for).and_return(true)
        allow(env).to receive(:[]).and_call_original
        allow(env).to receive(:[]).with(:interrupted).and_return(false)
        allow(env).to receive(:[]).with(:ip_address).and_return('192.168.121.2')
      end
      it 'should call the next hook' do
        expect(app).to receive(:call)
        expect(ui).to receive(:info).with('Waiting for domain to get an IP address...')
        expect(ui).to receive(:info).with('Waiting for SSH to become available...')
        expect(env[:machine].communicate).to receive(:ready?).and_return(true)
        expect(subject.call(env)).to be_nil
      end
    end
  end

  describe '#recover' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver).to receive(:get_domain).and_return(machine)
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver).to receive(:state)
        .and_return(:not_created)
      allow(env).to receive(:[]).and_call_original
    end

    it 'should do nothing by default' do
      expect(env).to_not receive(:[]).with(:action_runner) # cleanup
      expect(subject.recover(env)).to be_nil
    end

    context 'with machine coming up' do
      before do
        allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver).to receive(:state)
          .and_return(:running)
        env[:destroy_on_error] = true
      end

      context 'and user has disabled destroy on failure' do
        before do
          env[:destroy_on_error] = false
        end

        it 'skips terminate on failure' do
          expect(env).to_not receive(:[]).with(:action_runner) # cleanup
          expect(subject.recover(env)).to be_nil
        end
      end

      context 'and using default settings' do
        let(:runner) { double('runner') }
        it 'deletes VM on failure' do
          expect(env).to receive(:[]).with(:action_runner).and_return(runner) # cleanup
          expect(runner).to receive(:run)
          expect(subject.recover(env)).to be_nil
        end
      end
    end
  end
end
