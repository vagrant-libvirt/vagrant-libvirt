# frozen_string_literal: true

require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant-libvirt/action/prepare_nfs_settings'


describe VagrantPlugins::ProviderLibvirt::Action::PrepareNFSSettings do
  subject { described_class.new(app, env) }

  include_context 'unit'

  describe '#call' do
    before do
      # avoid requiring nfsd installed to run tests
      allow(machine.env.host).to receive(:capability?).with(:nfs_installed).and_return(true)
      allow(machine.env.host).to receive(:capability).with(:nfs_installed).and_return(true)
    end

    context 'when enabled' do
      let(:vagrantfile) do
        <<-EOF
        Vagrant.configure('2') do |config|
          config.vm.box = "vagrant-libvirt/test"
          config.vm.define :test
          config.vm.synced_folder ".", "/vagrant", type: "nfs"
          config.vm.provider :libvirt do |libvirt|
            #{vagrantfile_providerconfig}
          end
        end
        EOF
      end
      let(:socket) { double('socket') }

      before do
        allow(::TCPSocket).to receive(:new).and_return(socket)
        allow(socket).to receive(:close)
      end

      it 'should retrieve the guest IP address' do
        times_called = 0
        expect(::TCPSocket).to receive(:new) do
          # force reaching later code
          times_called += 1
          times_called < 2 ? raise("StandardError") : socket
        end
        expect(machine).to receive(:ssh_info).and_return({:host => '192.168.1.2'})
        expect(communicator).to receive(:execute).and_yield(:stdout, "192.168.1.2\n192.168.2.2")

        expect(subject.call(env)).to be_nil
      end
    end
  end
end
