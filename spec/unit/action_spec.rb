# frozen_string_literal: true

require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant/action/runner'

require 'vagrant-libvirt/action'


describe VagrantPlugins::ProviderLibvirt::Action do
  subject { described_class }

  include_context 'libvirt'
  include_context 'unit'

  let(:runner) { Vagrant::Action::Runner.new(env) }
  let(:state) { double('state') }

  before do
    allow(machine).to receive(:id).and_return('test-machine-id')
    allow(machine).to receive(:state).and_return(state)

    allow(logger).to receive(:info)
    allow(logger).to receive(:trace)
    allow(logger).to receive(:debug)
    allow(logger).to receive(:error)

    allow(connection.client).to receive(:libversion).and_return(6_002_000)

    # patch out iterating synced_folders by emptying the list returned
    # where vagrant us using a Collection, otherwise fallback to using
    # the env value to disable the behaviour for older versions.
    begin
      require 'vagrant/plugin/v2/synced_folder'

      synced_folders = Vagrant::Plugin::V2::SyncedFolder::Collection.new
      allow(machine).to receive(:synced_folders).and_return(synced_folders)
    rescue NameError
      env[:synced_folders_disable] = true
    end
  end

  def allow_action_env_result(action, *responses)
    results = responses.dup

    allow_any_instance_of(action).to receive(:call) do |cls, env|
      app = cls.instance_variable_get(:@app)

      env[:result] = results[0]
      if results.length > 1
        results.shift
      end

      app.call(env)
    end
  end

  describe '#action_halt' do
    context 'not created' do
      before do
        expect(state).to receive(:id).and_return(:not_created)
      end

      it 'should execute without error' do
        expect(ui).to receive(:info).with('Domain is not created. Please run `vagrant up` first.')

        expect(runner.run(subject.action_halt)).to match(hash_including({:machine => machine}))
      end
    end

    context 'running' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsSuspended, false)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, true)
      end

      context 'when shutdown domain works' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::ShutdownDomain, true)
          allow_action_env_result(Vagrant::Action::Builtin::GracefulHalt, true)
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, true, false)
        end

        it 'should skip calling HaltDomain' do
          expect(ui).to_not receive(:info).with('Domain is not created. Please run `vagrant up` first.')
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::HaltDomain).to_not receive(:call)

          expect(runner.run(subject.action_halt)).to match(hash_including({:machine => machine}))
        end
      end

      context 'when shutdown domain fails' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::ShutdownDomain, false)
          allow_action_env_result(Vagrant::Action::Builtin::GracefulHalt, false)
        end

        it 'should call halt' do
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::HaltDomain).to receive(:call)

          expect(runner.run(subject.action_halt)).to match(hash_including({:machine => machine}))
        end
      end
    end
  end

  describe '#action_ssh' do
    context 'when not created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, false)
      end

      it 'should cause an error' do
        expect{ machine.action(:ssh, ssh_opts: {})}.to raise_error(Vagrant::Errors::VMNotCreatedError)
      end
    end

    context 'when created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
      end

      context 'when not running' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, false)
        end

        it 'should cause an error' do
          expect{ machine.action(:ssh, ssh_opts: {})}.to raise_error(Vagrant::Errors::VMNotRunningError)
        end
      end

      context 'when running' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, true)
        end

        it 'should call SSHExec' do
          expect_any_instance_of(Vagrant::Action::Builtin::SSHExec).to receive(:call).and_return(0)
          expect(machine.action(:ssh, ssh_opts: {})).to match(hash_including({:action_name => :machine_action_ssh}))
        end
      end
    end
  end

  describe '#action_ssh_run' do
    context 'when not created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, false)
      end

      it 'should cause an error' do
        expect{ machine.action(:ssh_run, ssh_opts: {})}.to raise_error(Vagrant::Errors::VMNotCreatedError)
      end
    end

    context 'when created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
      end

      context 'when not running' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, false)
        end

        it 'should cause an error' do
          expect{ machine.action(:ssh_run, ssh_opts: {})}.to raise_error(Vagrant::Errors::VMNotRunningError)
        end
      end

      context 'when running' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, true)
        end

        it 'should call SSHRun' do
          expect_any_instance_of(Vagrant::Action::Builtin::SSHRun).to receive(:call).and_return(0)
          expect(machine.action(:ssh_run, ssh_opts: {})).to match(hash_including({:action_name => :machine_action_ssh_run}))
        end
      end
    end
  end

  describe '#action_snapshot_delete' do
    context 'when not created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, false)
      end

      it 'should cause an error' do
        expect{ machine.action(:snapshot_delete, snapshot_opts: {})}.to raise_error(Vagrant::Errors::VMNotCreatedError)
      end
    end

    context 'when created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
      end

      context 'when running' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, true)
        end

        it 'should call SnapshotDelete' do
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SnapshotDelete).to receive(:call).and_return(0)
          expect(machine.action(:snapshot_delete, snapshot_opts: {})).to match(hash_including({:action_name => :machine_action_snapshot_delete}))
        end
      end
    end
  end


  describe '#action_snapshot_restore' do
    context 'when not created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, false)
      end

      it 'should cause an error' do
        expect{ machine.action(:snapshot_restore, snapshot_opts: {})}.to raise_error(Vagrant::Errors::VMNotCreatedError)
      end
    end

    context 'when created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
      end

      context 'when running' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, true)
        end

        it 'should call SnapshotRestore' do
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SnapshotRestore).to receive(:call).and_return(0)
          expect(machine.action(:snapshot_restore, snapshot_opts: {})).to match(hash_including({:action_name => :machine_action_snapshot_restore}))
        end
      end
    end
  end

  describe '#action_snapshot_save' do
    context 'when not created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, false)
      end

      it 'should cause an error' do
        expect{ machine.action(:snapshot_save, snapshot_opts: {})}.to raise_error(Vagrant::Errors::VMNotCreatedError)
      end
    end

    context 'when created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
      end

      context 'when running' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, true)
        end

        it 'should call SnapshotSave' do
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SnapshotSave).to receive(:call).and_return(0)
          expect(machine.action(:snapshot_save, snapshot_opts: {})).to match(hash_including({:action_name => :machine_action_snapshot_save}))
        end
      end
    end
  end
end
