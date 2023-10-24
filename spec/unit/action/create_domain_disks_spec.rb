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
      let(:vagrantfile_providerconfig) do
        <<-EOF
        libvirt.qemu_use_session = true
        EOF
      end

      let(:disks) do
        [
          :device        => 'vdb',
          :cache         => 'default',
          :bus           => 'virtio',
          :type          => 'qcow2',
          :absolute_path => '/var/lib/libvirt/images/vagrant-test_default-vdb.qcow2',
          :virtual_size  => ByteNumber.new(20*1024*1024*1024),
          :pool          => 'default',
        ]
      end

      before do
        expect(Process).to receive(:uid).and_return(9999).at_least(:once)
        expect(Process).to receive(:gid).and_return(9999).at_least(:once)

        env[:disks] = disks
      end

      context 'volume create succeeded' do
        it 'should complete' do
          expect(volumes).to receive(:create).with(
            hash_including(
              :path        => "/var/lib/libvirt/images/vagrant-test_default-vdb.qcow2",
              :owner       => 9999,
              :group       => 9999,
              :pool_name   => "default",
            )
          )

          expect(subject.call(env)).to be_nil
        end
      end
    end
  end
end
