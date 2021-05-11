require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'

require 'vagrant-libvirt/action/destroy_domain'

describe VagrantPlugins::ProviderLibvirt::Action::HandleBoxImage do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:libvirt_client) { double('libvirt_client') }
  let(:volumes) { double('volumes') }
  let(:all) { double('all') }
  let(:box_volume) { double('box_volume') }
  let(:fog_volume) { double('fog_volume') }

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:client).and_return(libvirt_client)
      allow(connection).to receive(:volumes).and_return(volumes)
      allow(volumes).to receive(:all).and_return(all)
      allow(env[:ui]).to receive(:clear_line)

    end

    context 'when one disk in metadata.json' do
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

      it 'should have one disk in machine env' do
        expect(subject.call(env)).to be_nil
        expect(env[:box_volume_number]).to eq(1)
        expect(env[:box_volumes]).to eq(
          [
            {
              :path=>"/test/box.img",
              :name=>"test_vagrant_box_image_1.1.1_0.img", 
              :virtual_size=>5,
              :format=>"qcow2"
            }
          ]
        )
      end

      context 'when disk image not in storage pool' do
        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:size).and_return(5*1024*1024*1024)
          allow(all).to receive(:first).and_return(nil)
          allow(subject).to receive(:upload_image).and_return(true)
          allow(volumes).to receive(:create).and_return(fog_volume)
        end

        it 'should upload disk' do
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_0.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            hash_including(
              :name => "test_vagrant_box_image_1.1.1_0.img",
              :allocation => "5120M",
              :capacity => "5G",
            )
          )
          expect(subject).to receive(:upload_image)
          expect(subject.call(env)).to be_nil
        end
      end

      context 'when disk image already in storage pool' do
        before do
          allow(all).to receive(:first).and_return(box_volume)
          allow(box_volume).to receive(:id).and_return(1)
        end

        it 'should skip disk upload' do
          expect(volumes).not_to receive(:create)
          expect(subject).not_to receive(:upload_image)
          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'when three disks in metadata.json' do
      let(:status) { double }

      before do
        allow(all).to receive(:first).and_return(box_volume)
        allow(box_volume).to receive(:id).and_return(1)
        allow(env[:machine]).to receive_message_chain("box.name") { 'test' }
        allow(env[:machine]).to receive_message_chain("box.version") { '1.1.1' }
        allow(env[:machine]).to receive_message_chain("box.metadata") { Hash[
          'disks' => [
            {
              'name'=>'send_box_name.img',
            },
            {
              'path' => 'disk.qcow2',
            },
            { },
          ],
        ]}
        allow(env[:machine]).to receive_message_chain("box.directory.join") do |arg|
          '/test/'.concat(arg.to_s)
        end
        allow(status).to receive(:success?).and_return(true)
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', '/test/box.img').and_return([
            "image: /test/box.img\nfile format: qcow2\nvirtual size: 5 GiB (5368709120 bytes)\ndisk size: 1.45 GiB\n", "", status
        ])
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', '/test/disk.qcow2').and_return([
          "image: /test/disk.qcow2\nfile format: qcow2\nvirtual size: 10 GiB (10737418240 bytes)\ndisk size: 1.45 GiB\n", "", status
        ])
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', '/test/box_2.img').and_return([
          "image: /test/box_2.img\nfile format: qcow2\nvirtual size: 20 GiB (21474836480 bytes)\ndisk size: 1.45 GiB\n", "", status
        ])
      end

      it 'should have three disks in machine env' do
        expect(subject.call(env)).to be_nil
        expect(env[:box_volume_number]).to eq(3)
        expect(env[:box_volumes]).to eq(
          [
            {
              :path=>"/test/box.img",
              :name=>"send_box_name.img",
              :virtual_size=>5,
              :format=>"qcow2"
            },
            {
              :path=>"/test/disk.qcow2",
              :name=>"test_vagrant_box_image_1.1.1_1.img", 
              :virtual_size=>10,
              :format=>"qcow2"
            },
            {
              :path=>"/test/box_2.img",
              :name=>"test_vagrant_box_image_1.1.1_2.img", 
              :virtual_size=>20,
              :format=>"qcow2"
            }
          ]
        )
      end

      context 'when none of the disks in storage pool' do
        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:size).and_return(5*1024*1024*1024, 10*1024*1024*1024, 20*1024*1024*1024)
          allow(all).to receive(:first).and_return(nil)
          allow(subject).to receive(:upload_image).and_return(true)
          allow(volumes).to receive(:create).and_return(fog_volume)
        end

        it 'should upload all 3 disks' do
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume send_box_name.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            hash_including(
              :name => "send_box_name.img",
              :allocation => "5120M",
              :capacity => "5G",
            )
          )
          expect(subject).to receive(:upload_image)
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_1.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            hash_including(
              :name => "test_vagrant_box_image_1.1.1_1.img",
              :allocation => "10240M",
              :capacity => "10G",
            )
          )
          expect(subject).to receive(:upload_image)
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_2.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            hash_including(
              :name => "test_vagrant_box_image_1.1.1_2.img",
              :allocation => "20480M",
              :capacity => "20G",
            )
          )
          expect(subject).to receive(:upload_image)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'when only disk 0 in storage pool' do
        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:size).and_return(10*1024*1024*1024, 20*1024*1024*1024)
          allow(all).to receive(:first).and_return(box_volume, nil, nil)
          allow(box_volume).to receive(:id).and_return(1)
          allow(subject).to receive(:upload_image).and_return(true)
          allow(volumes).to receive(:create).and_return(fog_volume)
        end

        it 'upload disks 1 and 2 only' do
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_1.img in storage pool default.')
          expect(volumes).to receive(:create).with(hash_including(:name => "test_vagrant_box_image_1.1.1_1.img"))
          expect(subject).to receive(:upload_image)
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_2.img in storage pool default.')
          expect(volumes).to receive(:create).with(hash_including(:name => "test_vagrant_box_image_1.1.1_2.img"))
          expect(subject).to receive(:upload_image)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'when has all disks on storage pool' do
        before do
          allow(all).to receive(:first).and_return(box_volume)
          allow(box_volume).to receive(:id).and_return(1)
        end

        it 'should skip disk upload' do
          expect(ui).not_to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(volumes).not_to receive(:create)
          expect(subject).not_to receive(:upload_image)
          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'when wrong box format in metadata.json' do
      before do
        allow(all).to receive(:first).and_return(box_volume)
        allow(box_volume).to receive(:id).and_return(1)
        allow(env[:machine]).to receive_message_chain("box.name") { 'test' }
        allow(env[:machine]).to receive_message_chain("box.version") { '1.1.1' }
        allow(env[:machine]).to receive_message_chain("box.metadata") { Hash[
          'virtual_size'=> 5,
          'format' => 'wrongFormat'
          ]
        }
        allow(env[:machine]).to receive_message_chain("box.directory.join") do |arg|
          '/test/'.concat(arg.to_s)
        end
      end

      it 'should raise WrongBoxFormatSet exception' do
        expect{ subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::WrongBoxFormatSet)
      end

    end

    context 'when one of a multi disk definition has wrong disk format in metadata.json' do
      let(:status) { double }

      before do
        allow(all).to receive(:first).and_return(box_volume)
        allow(box_volume).to receive(:id).and_return(1)
        allow(env[:machine]).to receive_message_chain("box.name") { 'test' }
        allow(env[:machine]).to receive_message_chain("box.version") { '1.1.1' }
        allow(env[:machine]).to receive_message_chain("box.metadata") {
          Hash[
            'disks' => [
              {
                'name'=>'send_box_name.img',
                'format'=> 'wrongFormat'
              },
              {
                'path' => 'disk.qcow2',
              },
              { },
            ],
          ]
        }
        allow(env[:machine]).to receive_message_chain("box.directory.join") do |arg|
          '/test/'.concat(arg.to_s)
        end
        allow(status).to receive(:success?).and_return(true)
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', '/test/box.img').and_return([
            "image: /test/box.img\nfile format: qcow2\nvirtual size: 5 GiB (5368709120 bytes)\ndisk size: 1.45 GiB\n", "", status
        ])
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', '/test/disk.qcow2').and_return([
          "image: /test/disk.qcow2\nfile format: qcow2\nvirtual size: 10 GiB (10737418240 bytes)\ndisk size: 1.45 GiB\n", "", status
        ])
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', '/test/box_2.img').and_return([
          "image: /test/box_2.img\nfile format: qcow2\nvirtual size: 20 GiB (21474836480 bytes)\ndisk size: 1.45 GiB\n", "", status
        ])
      end

      it 'should be ignored' do
        expect(subject.call(env)).to be_nil
      end
    end

  end
end
