require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'
require 'vagrant-libvirt/action/destroy_domain'

describe VagrantPlugins::ProviderLibvirt::Action::HaltDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:libvirt_domain) { double('libvirt_domain') }
  let(:servers) { double('servers') }

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)
      # always see this at the start of #call
      expect(ui).to receive(:info).with('Halting domain...')
    end

    context 'with graceful timeout' do
      it "should shutdown" do
        expect(guest).to receive(:capability).with(:halt).and_return(true)
        expect(domain).to receive(:wait_for).with(60).and_return(false)
        expect(subject.call(env)).to be_nil
      end

      context 'when halt fails' do
        before do
          expect(logger).to receive(:info).with('Trying Libvirt graceful shutdown.')
          expect(guest).to receive(:capability).with(:halt).and_raise(IOError)
          expect(domain).to receive(:state).and_return('running')
        end

        it "should call shutdown" do
          expect(domain).to receive(:shutdown)
          expect(domain).to receive(:wait_for).with(60).and_return(false)
          expect(subject.call(env)).to be_nil
        end

        context 'when shutdown fails' do
          it "should call power off" do
            expect(logger).to receive(:error).with('Failed to shutdown cleanly. Calling force poweroff.')
            expect(domain).to receive(:shutdown).and_raise(IOError)
            expect(domain).to receive(:poweroff)
            expect(subject.call(env)).to be_nil
          end
        end

        context 'when shutdown exceeds the timeout' do
          it "should call poweroff" do
            expect(logger).to receive(:info).with('VM is still running. Calling force poweroff.')
            expect(domain).to receive(:shutdown).and_raise(Timeout::Error)
            expect(domain).to receive(:poweroff)
            expect(subject.call(env)).to be_nil
          end
        end
      end

      context 'when halt exceeds the timeout' do
        before do
          expect(logger).to_not receive(:info).with('Trying Libvirt graceful shutdown.')
          expect(guest).to receive(:capability).with(:halt).and_raise(Timeout::Error)
        end

        it "should call poweroff" do
          expect(logger).to receive(:info).with('VM is still running. Calling force poweroff.')
          expect(domain).to receive(:poweroff)
          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'with force halt enabled' do
      before do
        allow(env).to receive(:[]).and_call_original
        expect(env).to receive(:[]).with(:force_halt).and_return(true)
      end

      it "should just call poweroff" do
        expect(domain).to receive(:poweroff)
        expect(subject.call(env)).to be_nil
      end
    end
  end
end
