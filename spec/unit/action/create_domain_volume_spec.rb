# frozen_string_literal: true

require 'spec_helper'

require 'fog/libvirt/models/compute/volume'

require 'vagrant-libvirt/action/destroy_domain'
require 'vagrant-libvirt/util/byte_number'


describe VagrantPlugins::ProviderLibvirt::Action::CreateDomainVolume do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:volumes) { double('volumes') }
  let(:all) { double('all') }
  let(:box_volume) { instance_double(::Fog::Libvirt::Compute::Volume) }

  def read_test_file(name)
    File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), name))
  end

  describe '#call' do
    before do
      allow(connection).to receive(:volumes).and_return(volumes)
      allow(volumes).to receive(:all).and_return(all)
      allow(all).to receive(:first).and_return(box_volume)
      allow(box_volume).to receive(:id).and_return(nil)
      env[:domain_name] = 'test'

      allow(machine.provider_config).to receive(:qemu_use_session).and_return(false)

      allow(logger).to receive(:debug)
    end

    context 'when one disk' do
      before do
        allow(box_volume).to receive(:path).and_return('/test/path_0.img')
        env[:box_volumes] = [
          {
            :name=>"test_vagrant_box_image_1.1.1_0.img",
            :virtual_size=>ByteNumber.new(5368709120)
          }
        ]
      end

      it 'should create one disk in storage' do
        expected_xml = read_test_file('one_disk_in_storage.xml')
        expect(ui).to receive(:info).with('Creating image (snapshot of base box volume).')
        expect(logger).to receive(:debug).with('Using pool default for base box snapshot')
        expect(volumes).to receive(:create).with(
          :xml => expected_xml,
          :pool_name => "default"
        )
        expect(subject.call(env)).to be_nil
      end
    end

    context 'when three disks' do
      before do
        allow(box_volume).to receive(:path).and_return(
          '/test/path_0.img',
          '/test/path_1.img',
          '/test/path_2.img',
        )
        env[:box_volumes] = [
          {
            :name=>"test_vagrant_box_image_1.1.1_0.img",
            :virtual_size=>ByteNumber.new(5368709120)
          },
          {
            :name=>"test_vagrant_box_image_1.1.1_1.img",
            :virtual_size=>ByteNumber.new(10737423360)
          },
          {
            :name=>"test_vagrant_box_image_1.1.1_2.img",
            :virtual_size=>ByteNumber.new(21474836480)
          }
        ]
      end

      it 'should create three disks in storage' do
        expect(ui).to receive(:info).with('Creating image (snapshot of base box volume).')
        expect(logger).to receive(:debug).with('Using pool default for base box snapshot')
        expect(volumes).to receive(:create).with(
          :xml => read_test_file('three_disks_in_storage_disk_0.xml'),
          :pool_name => "default"
        )
        expect(logger).to receive(:debug).with('Using pool default for base box snapshot')
        expect(volumes).to receive(:create).with(
          :xml => read_test_file('three_disks_in_storage_disk_1.xml'),
          :pool_name => "default"
        )
        expect(logger).to receive(:debug).with('Using pool default for base box snapshot')
        expect(volumes).to receive(:create).with(
          :xml => read_test_file('three_disks_in_storage_disk_2.xml'),
          :pool_name => "default"
        )
        expect(subject.call(env)).to be_nil
      end
    end
  end
end
