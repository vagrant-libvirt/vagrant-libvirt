require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'
require 'vagrant-libvirt/action/shutdown_domain'

describe VagrantPlugins::ProviderLibvirt::Action::StartShutdownTimer do
  subject { described_class.new(app, env) }

  include_context 'unit'

  describe '#call' do
    it 'should set shutdown_start_time' do
      expect(env[:shutdown_start_time]).to eq(nil)
      expect(subject.call(env)).to eq(nil)
      expect(env[:shutdown_start_time]).to_not eq(nil)
    end
  end
end

describe VagrantPlugins::ProviderLibvirt::Action::ShutdownDomain do
  subject { described_class.new(app, env, target_state, current_state) }

  include_context 'unit'
  include_context 'libvirt'

  let(:driver) { double('driver') }
  let(:libvirt_domain) { double('libvirt_domain') }
  let(:servers) { double('servers') }
  let(:current_state) { :running }
  let(:target_state) { :shutoff }

  before do
    allow(machine.provider).to receive('driver').and_return(driver)
    allow(driver).to receive(:created?).and_return(true)
    allow(driver).to receive(:connection).and_return(connection)
  end

  describe '#call' do
    before do
      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)
      allow(ui).to receive(:info).with('Attempting direct shutdown of domain...')
      allow(env).to receive(:[]).and_call_original
      allow(env).to receive(:[]).with(:shutdown_start_time).and_return(Time.now)
    end

    context "when state is shutoff" do
      before do
        allow(driver).to receive(:state).and_return(:shutoff)
      end

      it "should not shutdown" do
        expect(domain).not_to receive(:shutoff)
        subject.call(env)
      end

      it "should not print shutdown message" do
        expect(ui).not_to receive(:info)
        subject.call(env)
      end

      it "should provide a true result" do
        subject.call(env)
        expect(env[:result]).to be_truthy
      end
    end

    context "when state is running" do
      before do
        allow(driver).to receive(:state).and_return(:running)
      end

      it "should shutdown" do
        expect(domain).to receive(:wait_for)
        expect(domain).to receive(:shutdown)
        subject.call(env)
      end

      it "should print shutdown message" do
        expect(domain).to receive(:wait_for)
        expect(domain).to receive(:shutdown)
        expect(ui).to receive(:info).with('Attempting direct shutdown of domain...')
        subject.call(env)
      end

      context "when final state is not shutoff" do
        before do
          expect(driver).to receive(:state).and_return(:running).exactly(3).times
          expect(domain).to receive(:wait_for)
          expect(domain).to receive(:shutdown)
        end

        it "should provide a false result" do
          subject.call(env)
          expect(env[:result]).to be_falsey
        end
      end

      context "when final state is shutoff" do
        before do
          expect(driver).to receive(:state).and_return(:running).exactly(2).times
          expect(driver).to receive(:state).and_return(:shutoff).exactly(1).times
          expect(domain).to receive(:wait_for)
          expect(domain).to receive(:shutdown)
        end

        it "should provide a true result" do
          subject.call(env)
          expect(env[:result]).to be_truthy
        end
      end

      context "when timeout exceeded" do
        before do
          expect(machine).to receive_message_chain('config.vm.graceful_halt_timeout').and_return(1)
          expect(Time).to receive(:now).and_return(env[:shutdown_start_time] + 2)
          expect(driver).to receive(:state).and_return(:running).exactly(1).times
          expect(domain).to_not receive(:wait_for)
          expect(domain).to_not receive(:shutdown)
        end

        it "should provide a false result" do
          subject.call(env)
          expect(env[:result]).to be_falsey
        end
      end

      context "when timeout not exceeded" do
        before do
          expect(machine).to receive_message_chain('config.vm.graceful_halt_timeout').and_return(2)
          expect(Time).to receive(:now).and_return(env[:shutdown_start_time] + 1.5)
          expect(driver).to receive(:state).and_return(:running).exactly(3).times
          expect(domain).to receive(:wait_for) do |time|
            expect(time).to be < 1
            expect(time).to be > 0
          end
          expect(domain).to receive(:shutdown)
        end

        it "should wait for the reduced time" do
          subject.call(env)
          expect(env[:result]).to be_falsey
        end
      end
    end

    context "when required action not run" do
      before do
        expect(env).to receive(:[]).with(:shutdown_start_time).and_call_original
      end

      it "should raise an exception" do
        expect { subject.call(env) }.to raise_error(
          VagrantPlugins::ProviderLibvirt::Errors::CallChainError,
          /Invalid action chain, must ensure that '.*ShutdownTimer' is called prior to calling '.*ShutdownDomain'/
        )
      end
    end
  end
end
