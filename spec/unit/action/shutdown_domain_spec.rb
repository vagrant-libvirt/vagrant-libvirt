require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'
require 'vagrant-libvirt/action/shutdown_domain'

describe VagrantPlugins::ProviderLibvirt::Action::ShutdownDomain do
  subject { described_class.new(app, env, target_state, current_state) }

  include_context 'unit'
  include_context 'libvirt'

  let(:libvirt_domain) { double('libvirt_domain') }
  let(:servers) { double('servers') }
  let(:current_state) { :running }
  let(:target_state) { :shutoff }

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)
      allow(ui).to receive(:info).with('Attempting direct shutdown of domain...')
    end

    context "when state is shutoff" do
      before { allow(domain).to receive(:state).and_return('shutoff') }

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
        allow(domain).to receive(:state).and_return('running')
        allow(domain).to receive(:wait_for)
        allow(domain).to receive(:shutdown)
      end

      it "should shutdown" do
        expect(domain).to receive(:shutdown)
        subject.call(env)
      end

      it "should print shutdown message" do
        expect(ui).to receive(:info).with('Attempting direct shutdown of domain...')
        subject.call(env)
      end

      it "should wait for machine to shutdown" do
        expect(domain).to receive(:wait_for)
        subject.call(env)
      end

      context "when final state is not shutoff" do
        before do
          expect(domain).to receive(:state).and_return('running').exactly(6).times
        end

        it "should provide a false result" do
          subject.call(env)
          expect(env[:result]).to be_falsey
        end
      end

      context "when final state is shutoff" do
        before do
          expect(domain).to receive(:state).and_return('running').exactly(4).times
          expect(domain).to receive(:state).and_return('shutoff').exactly(2).times
        end

        it "should provide a true result" do
          subject.call(env)
          expect(env[:result]).to be_truthy
        end
      end

      context "when timeout exceeded" do
        before do
          expect(machine).to receive_message_chain('config.vm.graceful_halt_timeout').and_return(1)
          expect(app).to receive(:call) { sleep 1.5 }
          expect(domain).to receive(:state).and_return('running').exactly(2).times
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
          expect(app).to receive(:call) { sleep 1 }
          expect(domain).to receive(:state).and_return('running').exactly(6).times
          expect(domain).to receive(:wait_for) do |time|
            expect(time).to be < 1
            expect(time).to be > 0
          end
        end

        it "should wait for the reduced time" do
          subject.call(env)
          expect(env[:result]).to be_falsey
        end
      end
    end
  end
end
