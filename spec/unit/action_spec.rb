# frozen_string_literal: true

require_relative '../spec_helper'

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
    allow(logger).to receive(:warn)

    allow(connection.client).to receive(:libversion).and_return(6_002_000)

    # ensure runner available
    env[:action_runner] = runner

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
      call_next(cls, env) do |_, env|
        env[:result] = results[0]
        if results.length > 1
          results.shift
        end
      end
    end
  end

  def receive_and_call_next(&block)
    return receive(:call) { |cls, env| call_next(cls, env, &block) }.exactly(1).times
  end

  def call_next(cls, env)
    app = cls.instance_variable_get(:@app)

    yield(app, env) if block_given?

    app.call(env)
  end

  describe '#action_up' do
    before do
      # typically set by the up command
      env[:destroy_on_error] = true
    end

    context 'not created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, false)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsSuspended, false)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, false)
      end

      it 'should create a new machine' do
        expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CleanupOnFailure).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::HandleStoragePool).to receive_and_call_next
        expect_any_instance_of(Vagrant::Action::Builtin::HandleBox).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::HandleBoxImage).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateDomainVolume).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateDomain).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworkInterfaces).to receive_and_call_next

        # start action
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::PrepareNFSValidIds).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SyncedFolderCleanup).to receive_and_call_next
        expect_any_instance_of(Vagrant::Action::Builtin::SyncedFolders).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::PrepareNFSSettings).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ShareFolders).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetBootOrder).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::StartDomain).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::WaitTillUp).to receive_and_call_next
        expect_any_instance_of(Vagrant::Action::Builtin::WaitForCommunicator).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ForwardPorts).to receive_and_call_next

        # remaining up action
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetHostname).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetupComplete).to receive_and_call_next

        expect(runner.run(subject.action_up)).to match(hash_including({:machine => machine}))
      end

      context 'no box' do
        before do
          machine.config.vm.box = nil
        end

        it 'should create a new machine' do
          expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CleanupOnFailure).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateDomain).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworkInterfaces).to receive_and_call_next

          # start action
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetBootOrder).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::StartDomain).to receive_and_call_next

          # remaining up action
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetupComplete).to receive_and_call_next

          expect(runner.run(subject.action_up)).to match(hash_including({:machine => machine}))
        end
      end

      context 'on error' do
        it 'should cleanup on error' do
          expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::HandleStoragePool).to receive_and_call_next
          expect_any_instance_of(Vagrant::Action::Builtin::HandleBox).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::HandleBoxImage).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateDomainVolume).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateDomain).to receive_and_call_next
          # setup for error
          expect(state).to receive(:id).and_return(:created)
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive(:call).and_raise(
            ::VagrantPlugins::ProviderLibvirt::Errors::CreateNetworkError.new(:error_message => 'errmsg')
          )
          expect(subject).to receive(:action_destroy).and_return(Vagrant::Action::Builder.new)

          # remaining up
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetupComplete).to_not receive(:call)

          expect { runner.run(subject.action_up) }.to raise_error(::VagrantPlugins::ProviderLibvirt::Errors::CreateNetworkError)
        end

        it 'should do nothing if already finished setup' do
          expect(state).to receive(:id).and_return(:created)
          expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
          # don't intercept CleanupOnFailure or SetupComplete
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive(:call) do |cls, env|
            app = cls.instance_variable_get(:@app)

            app.call(env)

            raise Vagrant::Errors::VagrantError.new
          end
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::HandleStoragePool).to receive_and_call_next
          expect_any_instance_of(Vagrant::Action::Builtin::HandleBox).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::HandleBoxImage).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateDomainVolume).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateDomain).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworkInterfaces).to receive_and_call_next

          # start action
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::PrepareNFSValidIds).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SyncedFolderCleanup).to receive_and_call_next
          expect_any_instance_of(Vagrant::Action::Builtin::SyncedFolders).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::PrepareNFSSettings).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ShareFolders).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetBootOrder).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::StartDomain).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::WaitTillUp).to receive_and_call_next
          expect_any_instance_of(Vagrant::Action::Builtin::WaitForCommunicator).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ForwardPorts).to receive_and_call_next

          # remaining up action
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetHostname).to receive_and_call_next

          expect(subject).to_not receive(:action_destroy)
          expect(subject).to_not receive(:action_halt)

          expect { runner.run(subject.action_up) }.to raise_error(::Vagrant::Errors::VagrantError)
        end
      end
    end

    context 'halted' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsSuspended, false)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, false)
      end

      it 'should start existing machine' do
        expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CleanupOnFailure).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive_and_call_next

        # start action
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::PrepareNFSValidIds).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SyncedFolderCleanup).to receive_and_call_next
        expect_any_instance_of(Vagrant::Action::Builtin::SyncedFolders).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::PrepareNFSSettings).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ShareFolders).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetBootOrder).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::StartDomain).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::WaitTillUp).to receive_and_call_next
        expect_any_instance_of(Vagrant::Action::Builtin::WaitForCommunicator).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ForwardPorts).to receive_and_call_next

        # remaining up
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetupComplete).to receive_and_call_next

        expect(runner.run(subject.action_up)).to match(hash_including({:machine => machine}))
      end

      context 'no box' do
        before do
          machine.config.vm.box = nil
        end

        it 'should start existing machine' do
          expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CleanupOnFailure).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive_and_call_next

          # start action
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetBootOrder).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::StartDomain).to receive_and_call_next

          # remaining up
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetupComplete).to receive_and_call_next

          expect(runner.run(subject.action_up)).to match(hash_including({:machine => machine}))
        end
      end

      context 'on error' do
        it 'should call halt on error' do
          expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CleanupOnFailure).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
          # setup for error
          expect(state).to receive(:id).and_return(:created)
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive(:call).and_raise(
            ::VagrantPlugins::ProviderLibvirt::Errors::CreateNetworkError.new(:error_message => 'errmsg')
          )
          expect(subject).to receive(:action_halt).and_return(Vagrant::Action::Builder.new)

          # remaining up
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetupComplete).to_not receive(:call)

          expect { runner.run(subject.action_up) }.to raise_error(::VagrantPlugins::ProviderLibvirt::Errors::CreateNetworkError)
        end
      end
    end

    context 'suspended' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsSuspended, true)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, false)
      end

      it 'should resume existing machine' do
        expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CleanupOnFailure).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive_and_call_next

        # start action
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResumeDomain).to receive_and_call_next
        expect_any_instance_of(Vagrant::Action::Builtin::WaitForCommunicator).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ForwardPorts).to receive_and_call_next

        # remaining up
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetupComplete).to receive_and_call_next

        expect(runner.run(subject.action_up)).to match(hash_including({:machine => machine}))
      end

      context 'no box' do
        before do
          machine.config.vm.box = nil
        end

        it 'should resume existing machine' do
          expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CleanupOnFailure).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive_and_call_next

          # start action
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResumeDomain).to receive_and_call_next

          # remaining up
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetupComplete).to receive_and_call_next

          expect(runner.run(subject.action_up)).to match(hash_including({:machine => machine}))
        end
      end
    end

    context 'running' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, true)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsSuspended, false)
      end

      it 'should call provision' do
        expect_any_instance_of(Vagrant::Action::Builtin::BoxCheckOutdated).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
        # ideally following two actions should not be scheduled if the machine is already running
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetupComplete).to receive_and_call_next

        expect(runner.run(subject.action_up)).to match(hash_including({:machine => machine}))
      end
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

        it 'should clear forwarded ports' do
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ClearForwardedPorts).to receive(:call)
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

  describe '#action_reload' do
    context 'when not created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, false)
      end

      it 'should report not created' do
        expect(ui).to receive(:info).with('Domain is not created. Please run `vagrant up` first.')

        expect(runner.run(subject.action_reload)).to match(hash_including({:machine => machine}))
      end
    end

    context 'when halted' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsSuspended, false)
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, false)
      end

      it 'should call reload' do
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::Provision).to receive_and_call_next
        expect(subject).to receive(:action_halt).and_return(Vagrant::Action::Builder.new)
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResolveDiskSettings).to receive_and_call_next

        # start action
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::PrepareNFSValidIds).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SyncedFolderCleanup).to receive_and_call_next
        expect_any_instance_of(Vagrant::Action::Builtin::SyncedFolders).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::PrepareNFSSettings).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ShareFolders).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SetBootOrder).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::StartDomain).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::WaitTillUp).to receive_and_call_next
        expect_any_instance_of(Vagrant::Action::Builtin::WaitForCommunicator).to receive_and_call_next
        expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ForwardPorts).to receive_and_call_next

        expect(runner.run(subject.action_reload)).to match(hash_including({:machine => machine}))
      end
    end
  end

  describe '#action_suspend' do
    context 'not created' do
      before do
        expect(state).to receive(:id).and_return(:not_created)
      end

      it 'should execute without error' do
        expect(ui).to receive(:info).with('Domain is not created. Please run `vagrant up` first.')

        expect(runner.run(subject.action_suspend)).to match(hash_including({:machine => machine}))
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

        it 'should clear ports and suspend the domain' do
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ClearForwardedPorts).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SuspendDomain).to receive_and_call_next

          expect(runner.run(subject.action_suspend)).to match(hash_including({:machine => machine}))
        end
      end

      context 'when not running' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsRunning, false)
        end

        it 'should report not running' do
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ClearForwardedPorts).to_not receive(:call)
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::SuspendDomain).to_not receive(:call)
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::MessageNotRunning).to receive_and_call_next

          expect(runner.run(subject.action_suspend)).to match(hash_including({:machine => machine}))
        end
      end
    end
  end

  describe '#action_resume' do
    context 'not created' do
      before do
        expect(state).to receive(:id).and_return(:not_created)
      end

      it 'should execute without error' do
        expect(ui).to receive(:info).with('Domain is not created. Please run `vagrant up` first.')

        expect(runner.run(subject.action_resume)).to match(hash_including({:machine => machine}))
      end
    end

    context 'when created' do
      before do
        allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsCreated, true)
      end

      context 'when suspended' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsSuspended, true)
        end

        it 'should setup networking resume domain and forward ports' do
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResumeDomain).to receive_and_call_next
          expect_any_instance_of(Vagrant::Action::Builtin::Provision).to receive_and_call_next
          expect_any_instance_of(Vagrant::Action::Builtin::WaitForCommunicator).to receive_and_call_next
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ForwardPorts).to receive_and_call_next

          expect(runner.run(subject.action_resume)).to match(hash_including({:machine => machine}))
        end
      end

      context 'when not suspended' do
        before do
          allow_action_env_result(VagrantPlugins::ProviderLibvirt::Action::IsSuspended, false)
        end

        it 'should report not running' do
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::CreateNetworks).to_not receive(:call)
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::ResumeDomain).to_not receive(:call)
          expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::MessageNotSuspended).to receive_and_call_next

          expect(runner.run(subject.action_resume)).to match(hash_including({:machine => machine}))
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
