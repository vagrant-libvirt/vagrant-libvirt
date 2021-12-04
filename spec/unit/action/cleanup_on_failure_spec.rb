# frozen_string_literal: true

require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant/action/runner'

require 'vagrant-libvirt/action'
require 'vagrant-libvirt/action/cleanup_on_failure'


describe VagrantPlugins::ProviderLibvirt::Action::CleanupOnFailure do
  subject { described_class }
  let(:callable_error) do
    Class.new do
      def initialize(app, env)
      end

      def self.name
        "TestAction"
      end

      def call(env)
        raise Exception, "some action failed"
      end
    end
  end

  include_context 'libvirt'
  include_context 'unit'

  let(:libvirt_domain) { double('libvirt_domain') }
  let(:runner) { Vagrant::Action::Runner.new(env) }
  let(:state) { double('state') }

  before do
    allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
      .to receive(:connection).and_return(connection)
    allow(machine).to receive(:id).and_return('test-machine-id')
    allow(machine).to receive(:state).and_return(state)

    allow(logger).to receive(:info)
    allow(logger).to receive(:debug)
    allow(logger).to receive(:error)

    allow(runner).to receive(:run).and_call_original
    env[:action_runner] = runner
    env[:destroy_on_error] = true
  end

  describe '#recover' do
    let(:action_chain) do
      Vagrant::Action::Builder.new.tap do |b|
        b.use subject
        b.use callable_error
      end
    end

    context 'not created' do
      before do
        expect(state).to receive(:id).and_return(:not_created)
      end

      it 'should return early' do
        expect(logger).to_not receive(:info).with('VM completed provider setup, no need to teardown')

        expect { runner.run(action_chain) }.to raise_error(Exception, "some action failed")
      end
    end

    context 'running' do
      before do
        allow(state).to receive(:id).and_return(:running)
      end

      it 'should destroy' do
        expect(VagrantPlugins::ProviderLibvirt::Action).to_not receive(:action_halt)
        expect(VagrantPlugins::ProviderLibvirt::Action).to receive(:action_destroy).and_return(Vagrant::Action::Builder.new)
        expect(logger).to_not receive(:info).with('VM completed provider setup, no need to teardown')

        expect { runner.run(action_chain) }.to raise_error(Exception, "some action failed")
      end

      context 'halt on error enabled' do
        before do
          env[:halt_on_error] = true
        end

        it 'should halt' do
          expect(VagrantPlugins::ProviderLibvirt::Action).to receive(:action_halt).and_return(Vagrant::Action::Builder.new)
          expect(VagrantPlugins::ProviderLibvirt::Action).to_not receive(:action_destroy)
          expect(logger).to_not receive(:info).with('VM completed provider setup, no need to teardown')

          expect { runner.run(action_chain) }.to raise_error(Exception, "some action failed")
        end
      end

      context 'destroy on error disabled' do
        before do
          env[:destroy_on_error] = false
        end

        it 'should not destroy' do
          expect(VagrantPlugins::ProviderLibvirt::Action).to_not receive(:action_halt)
          expect(VagrantPlugins::ProviderLibvirt::Action).to_not receive(:action_destroy)
          expect(logger).to_not receive(:info).with('VM completed provider setup, no need to teardown')

          expect { runner.run(action_chain) }.to raise_error(Exception, "some action failed")
        end
      end

      context 'completed setup' do
        let(:action_chain) do
          Vagrant::Action::Builder.new.tap do |b|
            b.use subject
            b.use VagrantPlugins::ProviderLibvirt::Action::SetupComplete
            b.use callable_error
          end
        end

        it 'should not perform halt or destroy' do
          expect(VagrantPlugins::ProviderLibvirt::Action).to_not receive(:action_halt)
          expect(VagrantPlugins::ProviderLibvirt::Action).to_not receive(:action_destroy)
          expect(logger).to receive(:debug).with('VM provider setup was completed, no need to halt/destroy')

          expect { runner.run(action_chain) }.to raise_error(Exception, "some action failed")
        end
      end
    end
  end
end
