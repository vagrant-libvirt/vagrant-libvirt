# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt'

describe 'VagrantPlugins::SyncedFolder9P::Cap::MountOptions' do
  include_context 'unit'

  def capability(name)
    VagrantPlugins::ProviderLibvirt::Plugin
      .components
      .synced_folder_capabilities[:"9p"]
      .get(name)
  end

  let(:options) { {} }
  let(:folder) { {
    :hostpath => '/home/test/default',
    :disabled => false,
    :guestpath => '/vagrant',
    :type => :"9p",
  }.merge(options) }

  describe '#mount_type' do
    it 'should be 9p' do
      expect(capability(:mount_type).mount_type(machine)).to eq('9p')
    end
  end

  describe '#mount_name' do
    it 'should use the mount tag the device was attached with' do
      expect(capability(:mount_name).mount_name(machine, '/vagrant', folder)).to eq(
        '1ef53e1c9b6a5a0c695c80665331652'
      )
    end

    context 'with mount tag already resolved' do
      let(:options) { { :mount_tag => 'already-resolved' } }

      it 'should reuse it' do
        expect(capability(:mount_name).mount_name(machine, '/vagrant', folder)).to eq(
          'already-resolved'
        )
      end
    end
  end

  describe '#mount_options' do
    subject do
      capability(:mount_options).mount_options(machine, '/vagrant', '/vagrant', folder)
    end

    it 'should mount via virtio and never fail the boot of the guest' do
      expect(subject).to eq(['trans=virtio,version=9p2000.L,nofail', nil, nil])
    end

    context 'with mount_options set' do
      let(:options) { { :mount_options => ['noatime'] } }

      it 'should keep them' do
        expect(subject).to eq(['trans=virtio,noatime,version=9p2000.L,nofail', nil, nil])
      end
    end

    context 'with mount_opts set' do
      let(:options) { { :mount_opts => 'msize=262144,noatime' } }

      it 'should keep them' do
        expect(subject).to eq(
          ['trans=virtio,version=9p2000.L,msize=262144,noatime,nofail', nil, nil]
        )
      end
    end

    context 'with version set' do
      let(:options) { { :version => '9p2000.u' } }

      it 'should use it instead of the default' do
        expect(subject).to eq(['trans=virtio,version=9p2000.u,nofail', nil, nil])
      end
    end

    context 'with access set' do
      let(:options) { { :access => 'user' } }

      it 'should pass it on' do
        expect(subject).to eq(['trans=virtio,access=user,version=9p2000.L,nofail', nil, nil])
      end
    end

    context 'with deprecated owner set' do
      let(:options) { { :owner => 'user' } }

      it 'should use it as access' do
        expect(subject).to eq(['trans=virtio,access=user,version=9p2000.L,nofail', nil, nil])
      end

      context 'with access set as well' do
        let(:options) { { :owner => 'ignored', :access => 'user' } }

        it 'should ignore the deprecated option' do
          expect(subject).to eq(['trans=virtio,access=user,version=9p2000.L,nofail', nil, nil])
        end
      end
    end

    context 'with mounting disabled' do
      let(:options) { { :mount => false } }

      it 'should not be mounted at boot' do
        expect(subject).to eq(['trans=virtio,version=9p2000.L,noauto,nofail', nil, nil])
      end
    end

    context 'with nofail already set' do
      let(:options) { { :mount_options => ['nofail'] } }

      it 'should not duplicate it' do
        expect(subject).to eq(['trans=virtio,nofail,version=9p2000.L', nil, nil])
      end
    end

    context 'with readonly set' do
      let(:options) { { :readonly => true } }

      it 'should mount read only' do
        expect(subject).to eq(['trans=virtio,version=9p2000.L,ro,nofail', nil, nil])
      end
    end
  end
end
