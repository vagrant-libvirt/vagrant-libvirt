require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'

require 'vagrant-libvirt/action/destroy_domain'

describe VagrantPlugins::ProviderLibvirt::Action::HandleBoxImage do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:libvirt_domain) { double('libvirt_domain') }
  let(:libvirt_client) { double('libvirt_client') }
  let(:driver) { double('driver') }
  let(:provider) { double('provider') }
  let(:volumes) { double('volumes') }
  let(:all) { double('all') }
  let(:box_volume) { double('box_volume') }
  let(:create) { double('create') }
  let(:fog_volume) { double('fog_volume') }
  let(:destroy) { double('destroy') }

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:client).and_return(libvirt_client)
      allow(connection).to receive(:volumes).and_return(volumes)
      allow(volumes).to receive(:all).and_return(all)
      allow(fog_volume).to receive(:destroy)
      allow(env[:ui]).to receive(:clear_line)

    end
    context 'When has one disk in metadata.json' do
      before do
        
        allow(all).to receive(:first).and_return(box_volume)
        allow(box_volume).to receive(:id).and_return(1)
        allow(env[:machine]).to receive_message_chain("box.name") { 'test' }
        allow(env[:machine]).to receive_message_chain("box.version") { '1.1.1' }
        allow(env[:machine]).to receive_message_chain("box.metadata") { Hash[
          'virtual_size'=> 5,
          'format' => 'qcow2'
          ]
        }
        allow(env[:machine]).to receive_message_chain("box.directory.join") do |arg|
          '/test/'.concat(arg.to_s)
        end
      end

      it 'we must have one disk in env' do
        expect(subject.call(env)).to be_nil
        expect(env[:box_volume_number]).to eq(1)
        expect(env[:box_volumes]).to eq(
          [
            {
              :path=>"/test/box.img",
              :name=>"test_vagrant_box_image_1.1.1_0.img", 
              :virtual_size=>5,
              :box_format=>"qcow2"
            }
          ]
        )
      end

      context 'when has no disk on storage pool' do
        let(:storage_uid) {0}
        let(:storage_gid) {0}

        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:size).and_return(5*1024*1024*1024)
          allow(all).to receive(:first).and_return(nil)
          allow(subject).to receive(:upload_image).and_return(true)
          allow(volumes).to receive(:create).and_return(fog_volume)
        end
        it 'Disk is sending' do
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_0.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            {
              :name => "test_vagrant_box_image_1.1.1_0.img",
              :allocation => "5120M",
              :capacity => "5G",
              :format_type => "qcow2",
              :owner => 0,
              :group => 0,
              :pool_name => "default"
            }
          )
          expect(subject).to receive(:upload_image)
          expect(subject.call(env)).to be_nil
        end
      end
      context 'when has disk on storage pool' do
        before do
          allow(all).to receive(:first).and_return(box_volume)
          allow(box_volume).to receive(:id).and_return(1)
        end
        it 'Disk is not sending' do
          expect(volumes).not_to receive(:create)
          expect(subject).not_to receive(:upload_image)
          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'When has three disk in metadata.json' do
      before do
        allow(all).to receive(:first).and_return(box_volume)
        allow(box_volume).to receive(:id).and_return(1)
        allow(env[:machine]).to receive_message_chain("box.name") { 'test' }
        allow(env[:machine]).to receive_message_chain("box.version") { '1.1.1' }
        allow(env[:machine]).to receive_message_chain("box.metadata") { Hash[
          'disks' => [
            {
              'name'=>'send_box_name.img',
              'virtual_size'=> 5,
            },
            {
              'path' => 'disk.qcow2',
              'virtual_size'=> 10
            },
            {'virtual_size'=> 20}
          ],
          'format' => 'qcow2'
          ]
        }
        allow(env[:machine]).to receive_message_chain("box.directory.join") do |arg|
          '/test/'.concat(arg.to_s)
        end
      end

      it 'we must have three disks in env' do
        expect(subject.call(env)).to be_nil
        expect(env[:box_volume_number]).to eq(3)
        expect(env[:box_volumes]).to eq(
          [
            {
              :path=>"/test/box.img",
              :name=>"send_box_name.img",
              :virtual_size=>5,
              :box_format=>"qcow2"
            },
            {
              :path=>"/test/disk.qcow2",
              :name=>"test_vagrant_box_image_1.1.1_1.img", 
              :virtual_size=>10,
              :box_format=>"qcow2"
            },
            {
              :path=>"/test/box_2.img",
              :name=>"test_vagrant_box_image_1.1.1_2.img", 
              :virtual_size=>20,
              :box_format=>"qcow2"
            }
          ]
        )
      end

      context 'when has no disk on storage pool' do
        let(:storage_uid) {0}
        let(:storage_gid) {0}

        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:size).and_return(5*1024*1024*1024, 10*1024*1024*1024, 20*1024*1024*1024)
          allow(all).to receive(:first).and_return(nil)
          allow(subject).to receive(:upload_image).and_return(true)
          allow(volumes).to receive(:create).and_return(fog_volume)
        end
        it 'Disk is sending' do
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume send_box_name.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            {
              :name => "send_box_name.img",
              :allocation => "5120M",
              :capacity => "5G",
              :format_type => "qcow2",
              :owner => 0,
              :group => 0,
              :pool_name => "default"
            }
          )
          expect(subject).to receive(:upload_image)
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_1.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            {
              :name => "test_vagrant_box_image_1.1.1_1.img",
              :allocation => "10240M",
              :capacity => "10G",
              :format_type => "qcow2",
              :owner => 0,
              :group => 0,
              :pool_name => "default"
            }
          )
          expect(subject).to receive(:upload_image)
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_2.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            {
              :name => "test_vagrant_box_image_1.1.1_2.img",
              :allocation => "20480M",
              :capacity => "20G",
              :format_type => "qcow2",
              :owner => 0,
              :group => 0,
              :pool_name => "default"
            }
          )
          expect(subject).to receive(:upload_image)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'when has only disk 0 on storage pool' do
        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:size).and_return(10*1024*1024*1024, 20*1024*1024*1024)
          allow(all).to receive(:first).and_return(box_volume, nil, nil)
          allow(box_volume).to receive(:id).and_return(1)
          allow(subject).to receive(:upload_image).and_return(true)
          allow(volumes).to receive(:create).and_return(fog_volume)
        end
        it 'Disk 1 and 2 is sending' do
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_1.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            {
              :name => "test_vagrant_box_image_1.1.1_1.img",
              :allocation => "10240M",
              :capacity => "10G",
              :format_type => "qcow2",
              :owner => 0,
              :group => 0,
              :pool_name => "default"
            }
          )
          expect(subject).to receive(:upload_image)
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_2.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            {
              :name => "test_vagrant_box_image_1.1.1_2.img",
              :allocation => "20480M",
              :capacity => "20G",
              :format_type => "qcow2",
              :owner => 0,
              :group => 0,
              :pool_name => "default"
            }
          )
          expect(subject).to receive(:upload_image)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'when has all disks on storage pool' do
        before do
          allow(all).to receive(:first).and_return(box_volume)
          allow(box_volume).to receive(:id).and_return(1)
        end
        it 'Disk is not sending' do
          expect(ui).not_to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(volumes).not_to receive(:create)
          expect(subject).not_to receive(:upload_image)
          expect(subject.call(env)).to be_nil
        end
      end
    end

  end
end
