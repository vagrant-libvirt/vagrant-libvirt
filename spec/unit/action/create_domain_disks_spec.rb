# frozen_string_literal: true

require_relative '../../spec_helper'

require 'fog/libvirt/models/compute/volume'

require 'vagrant-libvirt/action/create_domain_disks'

describe VagrantPlugins::ProviderLibvirt::Action::CreateDomainDisks do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:debug)
  end

  describe '#call' do

    let(:volumes) { double('volumes') }

    before do
      allow(connection).to receive(:volumes).and_return(volumes)
    end

    context 'additional disks' do

      let(:disks) do
        [
          {
            :device        => 'vdb',
            :cache         => 'default',
            :bus           => 'virtio',
            :type          => 'qcow2',
            :name          => 'vagrant-test_default-vdb.qcow2',
            :absolute_path => '/var/lib/libvirt/images/vagrant-test_default-vdb.qcow2',
            :virtual_size  => ByteNumber.new(20*1024*1024*1024),
            :pool          => 'default',
          },
        ]
      end

      before do
        env[:disks] = disks
      end

      context 'volume already exists' do
        let(:volume) { instance_double(::Fog::Libvirt::Compute::Volume) }

        before do
          allow(volumes).to receive(:all).and_return([volume])
          allow(volume).to receive(:id).and_return(1)
        end

        it 'should succeed and set :preexisting' do
          expect(subject.call(env)).to be_nil
          expect(disks[0][:preexisting]).to be(true)
        end
      end

      context 'volume needs uploading' do
        let(:tmp_fh) { Tempfile.new('vagrant-libvirt') }

        before do
          env[:disks][0][:path] = tmp_fh.path
          allow(volumes).to receive(:all).and_return([])
        end

        after do
          tmp_fh.delete
        end

        it 'should upload and succeed' do
          expect(subject).to receive(:storage_upload_image).and_return(true)

          expect(subject.call(env)).to be_nil
          expect(disks[0][:uploaded]).to be(true)
        end
      end

      context 'volume must be created' do

        before do
          allow(volumes).to receive(:all).and_return([])
        end

        it 'should succeed' do
          expect(disks[0][:path]).to be_nil
          expect(volumes).to receive(:create).and_return(nil)

          expect(subject.call(env)).to be_nil
        end

        it 'should fail' do
          expect(disks[0][:path]).to be_nil
          expect(volumes).to receive(:create).and_raise(Libvirt::Error)

          expect{ subject.call(env) }.to raise_error(
            VagrantPlugins::ProviderLibvirt::Errors::FogCreateDomainVolumeError
          )
        end
      end

    end
  end
end
