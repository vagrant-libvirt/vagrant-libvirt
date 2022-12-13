# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt'

describe 'VagrantPlugins::ProviderLibvirt::Cap::Mount9P' do
  include_context 'unit'

  subject do
    VagrantPlugins::ProviderLibvirt::Plugin
      .components
      .guest_capabilities[:linux]
      .get(:mount_9p_shared_folder)
  end

  let(:options) { {} }
  # Mock the guest operating system.
  let(:guest)            { double('guest') }

  describe '#mount_9p_shared_folder' do
    let(:synced_folders) { {
      "/vagrant" => {
        :hostpath => '/home/test/default',
        :disabled=>false,
        :guestpath=>'~/vagrant',
        :type => :"9p",
      }.merge(options),
    } }

    before do
      allow(machine).to receive(:guest).and_return(guest)
      allow(guest).to receive(:capability).and_return('/home/vagrant/vagant')
      allow(communicator).to receive(:sudo).with('mkdir -p /home/vagrant/vagant')
    end

    it 'should succeed' do
      expect(communicator).to receive(:sudo).with('modprobe 9p')
      expect(communicator).to receive(:sudo).with('modprobe 9pnet_virtio')
      expect(communicator).to receive(:sudo).with(/mount -t 9p.*/, instance_of(Hash))
      expect(ui).to_not receive(:warn)

      subject.mount_9p_shared_folder(machine, synced_folders)
    end

    context 'with owner option set' do
      let(:options) { {
        :owner=> 'user',
      } }

      it 'should warn option is deprecated' do
        expect(communicator).to receive(:sudo).with('modprobe 9p')
        expect(communicator).to receive(:sudo).with('modprobe 9pnet_virtio')
        expect(communicator).to receive(:sudo).with(
          /mount -t 9p -o trans=virtio,access=user .*/,
          instance_of(Hash))
        expect(ui).to receive(:warn).with(/`:owner` option for 9p mount options deprecated/)

        subject.mount_9p_shared_folder(machine, synced_folders)
      end

      context 'with access option set' do
        let(:options) { {
          :owner=> 'user',
          :access=> 'user',
        } }

        it 'should warn owner option is ignored' do
          expect(communicator).to receive(:sudo).with('modprobe 9p')
          expect(communicator).to receive(:sudo).with('modprobe 9pnet_virtio')
          expect(communicator).to receive(:sudo).with(/mount -t 9p.*/, instance_of(Hash))
          expect(ui).to receive(:warn).with(/deprecated `:owner` option ignored/)

          subject.mount_9p_shared_folder(machine, synced_folders)
        end
      end
    end
  end
end
