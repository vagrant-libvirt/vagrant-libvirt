# frozen_string_literal: true

require 'spec_helper'

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
      let(:udp_socket) { double('udp_socket') }

      before do
        allow(socket).to receive(:close)

        allow(::UDPSocket).to receive(:open).and_return(udp_socket)
        allow(udp_socket).to receive(:connect)
      end

      it 'should retrieve the guest IP address' do
        expect(::TCPSocket).to receive(:new).with('192.168.1.2', 'ssh').and_raise(StandardError)
        expect(::TCPSocket).to receive(:new).with('192.168.2.2', 'ssh').and_return(socket)
        expect(machine).to receive(:ssh_info).and_return({:host => '192.168.1.2'})
        expect(communicator).to receive(:execute).and_yield(:stdout, "192.168.1.2\n192.168.2.2")

        expect(subject.call(env)).to be_nil
      end

      it 'should use the ip if connection refused' do
        expect(::TCPSocket).to receive(:new).with('192.168.1.2', 'ssh').and_raise(Errno::ECONNREFUSED)
        expect(machine).to receive(:ssh_info).and_return({:host => '192.168.1.2'})

        expect(subject.call(env)).to be_nil
      end

      it 'should use the ssh port defined' do
        expect(::TCPSocket).to receive(:new).with('192.168.1.2', '2022').and_return(socket)
        expect(machine).to receive(:ssh_info).and_return({:host => '192.168.1.2', :port => '2022'})

        expect(subject.call(env)).to be_nil
      end

      it 'should raise an exception if machine ip not found' do
        expect(::TCPSocket).to receive(:new).with('192.168.1.2', 'ssh').and_raise(StandardError)
        expect(machine).to receive(:ssh_info).and_return({:host => '192.168.1.2'})
        expect(communicator).to receive(:execute).and_yield(:stdout, "192.168.1.2")

        expect { subject.call(env) }.to raise_error(::Vagrant::Errors::NFSNoHostonlyNetwork)
      end
    end
  end
end
