# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt'

describe 'VagrantPlugins::SyncedFolderVirtioFS::Cap::MountOptions' do
  include_context 'unit'

  def capability(name)
    VagrantPlugins::ProviderLibvirt::Plugin
      .components
      .synced_folder_capabilities[:virtiofs]
      .get(name)
  end

  let(:options) { {} }
  let(:folder) { {
    :hostpath => '/home/test/default',
    :disabled => false,
    :guestpath => '/vagrant',
    :type => :virtiofs,
  }.merge(options) }

  describe '#mount_type' do
    it 'should be virtiofs' do
      expect(capability(:mount_type).mount_type(machine)).to eq('virtiofs')
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

    it 'should never fail the boot of the guest' do
      expect(subject).to eq(['nofail', nil, nil])
    end

    context 'with mount_options set' do
      let(:options) { { :mount_options => ['noatime'] } }

      it 'should keep them' do
        expect(subject).to eq(['noatime,nofail', nil, nil])
      end
    end

    context 'with mount_opts set' do
      let(:options) { { :mount_opts => 'noatime,nodev' } }

      it 'should keep them' do
        expect(subject).to eq(['noatime,nodev,nofail', nil, nil])
      end
    end

    context 'with nofail already set' do
      let(:options) { { :mount_options => ['nofail'] } }

      it 'should not duplicate it' do
        expect(subject).to eq(['nofail', nil, nil])
      end
    end

    context 'with readonly set' do
      let(:options) { { :readonly => true } }

      it 'should mount read only' do
        expect(subject).to eq(['ro,nofail', nil, nil])
      end
    end
  end
end
