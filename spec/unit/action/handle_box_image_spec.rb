# frozen_string_literal: true

require_relative '../../spec_helper'

require 'json'

require 'vagrant-libvirt/action/handle_box_image'
require 'vagrant-libvirt/util/byte_number'


describe VagrantPlugins::ProviderLibvirt::Action::HandleBoxImage do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:volumes) { double('volumes') }
  let(:all) { double('all') }
  let(:box_volume) { double('box_volume') }
  let(:fog_volume) { double('fog_volume') }
  let(:config) { double('config') }

  qemu_json_return_5G = JSON.dump({
    "virtual-size": 5368709120,
    "filename": "/test/box.img",
    "cluster-size": 65536,
    "format": "qcow2",
    "actual-size": 655360,
    "dirty-flag": false
  })
  byte_number_5G = ByteNumber.new(5368709120)


  qemu_json_return_10G = JSON.dump({
    "virtual-size": 10737423360,
    "filename": "/test/disk.qcow2",
    "cluster-size": 65536,
    "format": "qcow2",
    "actual-size": 655360,
    "dirty-flag": false
  })
  byte_number_10G = ByteNumber.new(10737423360)

  qemu_json_return_20G = JSON.dump({
    "virtual-size": 21474836480,
    "filename": "/test/box_2.img",
    "cluster-size": 65536,
    "format": "qcow2",
    "actual-size": 1508708352,
    "dirty-flag": false
  })
  byte_number_20G = ByteNumber.new(21474836480)


  describe '#call' do
    before do
      allow(connection).to receive(:volumes).and_return(volumes)
      allow(volumes).to receive(:all).and_return(all)
      allow(env[:ui]).to receive(:clear_line)

      env[:machine].provider_config.disk_device = 'vda'
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
          '/test/' + arg.to_s
        end
      end

      it 'should have one disk in machine env' do
        expect(subject.call(env)).to be_nil
        expect(env[:box_volume_number]).to eq(1)
        expect(env[:box_volumes]).to eq(
          [
            {
              :path=>"/test/box.img",
              :name=>"test_vagrant_box_image_1.1.1_box.img",
              :virtual_size=>byte_number_5G,
              :format=>"qcow2",
              :device=>'vda',
              :compat=>"1.1",
            }
          ]
        )
      end

      context 'when no box version set' do
        let(:box_mtime) { Time.now }

        before do
          expect(env[:machine]).to receive_message_chain("box.version") { nil }
          expect(File).to receive(:mtime).and_return(box_mtime)
        end

        it 'should use the box file timestamp' do
          expect(ui).to receive(:warn).with(
            "No version detected for test, using timestamp to watch for modifications. Consider\n" +
            "generating a local metadata for the box with a version to allow better handling.\n" +
            'See https://www.vagrantup.com/docs/boxes/format#box-metadata for further details.'
          )

          expect(subject.call(env)).to be_nil
          expect(env[:box_volume_number]).to eq(1)
          expect(env[:box_volumes]).to eq(
            [
              {
                :path=>"/test/box.img",
                :name=>"test_vagrant_box_image_0_#{box_mtime.to_i}_box.img",
                :virtual_size=>byte_number_5G,
                :format=>"qcow2",
                :device=>'vda',
                :compat=>"1.1",
              }
            ]
          )
        end
      end

      context 'when box version set to 0' do
        let(:box_mtime) { Time.now }

        before do
          expect(env[:machine]).to receive_message_chain("box.version") { '0' }
          expect(File).to receive(:mtime).and_return(box_mtime)
        end

        it 'should use the box file timestamp' do
          expect(ui).to receive(:warn).with(/No version detected for test/)

          expect(subject.call(env)).to be_nil
          expect(env[:box_volume_number]).to eq(1)
          expect(env[:box_volumes]).to match([hash_including({:name=>"test_vagrant_box_image_0_#{box_mtime.to_i}_box.img"})])
        end
      end

      context 'When config.machine_virtual_size is set and smaller than box_virtual_size' do
        before do
          env[:machine].provider_config.machine_virtual_size = 1
        end
        it 'should warning must be raise' do
          expect(ui).to receive(:warn).with("Ignoring requested virtual disk size of '1' as it is below\nthe minimum box image size of '5'.")
          expect(subject.call(env)).to be_nil
          expect(env[:box_volumes]).to eq(
            [
              {
                :path=>"/test/box.img",
                :name=>"test_vagrant_box_image_1.1.1_box.img",
                :virtual_size=>byte_number_5G,
                :format=>"qcow2",
                :device=>'vda',
                :compat=>"1.1",
              }
            ]
          )
        end
      end

      context 'When config.machine_virtual_size is set and higher than box_virtual_size' do
        before do
          env[:machine].provider_config.machine_virtual_size = 20
        end
        it 'should be use' do
          expect(ui).to receive(:info).with("Created volume larger than box defaults, will require manual resizing of\nfilesystems to utilize.")
          expect(subject.call(env)).to be_nil
          expect(env[:box_volumes]).to eq(
            [
              {
                :path=>"/test/box.img",
                :name=>"test_vagrant_box_image_1.1.1_box.img",
                :virtual_size=>byte_number_20G,
                :format=>"qcow2",
                :device=>'vda',
                :compat=>"1.1",
              }
            ]
          )
        end
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
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_box.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            hash_including(
              :name => "test_vagrant_box_image_1.1.1_box.img",
              :allocation => "5120M",
              :capacity => "5368709120B",
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
              'path' => 'box.img',
              'name' => 'send_box_name',
            },
            {
              'path' => 'disk.qcow2',
            },
            {
              'path' => 'box_2.img',
            },
          ],
        ]}
        allow(env[:machine]).to receive_message_chain("box.directory.join") do |arg|
          '/test/' + arg.to_s
        end
        allow(status).to receive(:success?).and_return(true)
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', '--output=json', '/test/box.img').and_return([
          qemu_json_return_5G, "", status
        ])
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', '--output=json', '/test/disk.qcow2').and_return([
          qemu_json_return_10G, "", status
        ])
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', '--output=json', '/test/box_2.img').and_return([
          qemu_json_return_20G, "", status
        ])
      end

      it 'should have three disks in machine env' do
        expect(subject.call(env)).to be_nil
        expect(env[:box_volume_number]).to eq(3)
        expect(env[:box_volumes]).to eq(
          [
            {
              :path=>"/test/box.img",
              :name=>"test_vagrant_box_image_1.1.1_send_box_name.img",
              :virtual_size=>byte_number_5G,
              :format=>"qcow2",
              :device=>'vda',
              :compat=>"0.10"
            },
            {
              :path=>"/test/disk.qcow2",
              :name=>"test_vagrant_box_image_1.1.1_disk.img",
              :virtual_size=>byte_number_10G,
              :format=>"qcow2",
              :compat=>"0.10"
            },
            {
              :path=>"/test/box_2.img",
              :name=>"test_vagrant_box_image_1.1.1_box_2.img",
              :virtual_size=>byte_number_20G,
              :format=>"qcow2",
              :compat=>"0.10"
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
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_send_box_name.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            hash_including(
              :name => "test_vagrant_box_image_1.1.1_send_box_name.img",
              :allocation => "5120M",
              :capacity => "5368709120B",
            )
          )
          expect(subject).to receive(:upload_image)
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_disk.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            hash_including(
              :name => "test_vagrant_box_image_1.1.1_disk.img",
              :allocation => "10240M",
              :capacity => "10737423360B",
            )
          )
          expect(subject).to receive(:upload_image)
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_box_2.img in storage pool default.')
          expect(volumes).to receive(:create).with(
            hash_including(
              :name => "test_vagrant_box_image_1.1.1_box_2.img",
              :allocation => "20480M",
              :capacity => "21474836480B",
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
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_disk.img in storage pool default.')
          expect(volumes).to receive(:create).with(hash_including(:name => "test_vagrant_box_image_1.1.1_disk.img"))
          expect(subject).to receive(:upload_image)
          expect(ui).to receive(:info).with('Uploading base box image as volume into Libvirt storage...')
          expect(logger).to receive(:info).with('Creating volume test_vagrant_box_image_1.1.1_box_2.img in storage pool default.')
          expect(volumes).to receive(:create).with(hash_including(:name => "test_vagrant_box_image_1.1.1_box_2.img"))
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
          '/test/' + arg.to_s
        end
      end

      it 'should raise WrongBoxFormatSet exception' do
        expect{ subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::WrongBoxFormatSet)
      end

    end

    context 'when invalid format in metadata.json' do
      let(:status) { double }

      before do
        allow(all).to receive(:first).and_return(box_volume)
        allow(box_volume).to receive(:id).and_return(1)
        allow(env[:machine]).to receive_message_chain("box.name") { 'test' }
        allow(env[:machine]).to receive_message_chain("box.version") { '1.1.1' }
        allow(env[:machine]).to receive_message_chain("box.metadata") { box_metadata }
        allow(env[:machine]).to receive_message_chain("box.directory.join") do |arg|
          '/test/' + arg.to_s
        end
        allow(status).to receive(:success?).and_return(true)
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', "--output=json", '/test/box.img').and_return([
          qemu_json_return_5G, "", status
        ])
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', "--output=json", '/test/disk.qcow2').and_return([
          qemu_json_return_10G, "", status
        ])
        allow(Open3).to receive(:capture3).with('qemu-img', 'info', "--output=json", '/test/box_2.img').and_return([
          qemu_json_return_20G, "", status
        ])
      end

      context 'with one disk having wrong disk format' do
        let(:box_metadata) {
          Hash[
            'disks' => [
              {
                'path'   => 'box.img',
                'name'   =>'send_box_name.img',
                'format' => 'wrongFormat'
              },
              {
                'path' => 'disk.qcow2',
              },
              {
                'path' => 'box_2.img',
              },
            ],
          ]
        }

        it 'should be ignored' do
          expect(subject.call(env)).to be_nil
        end
      end

      context 'with one disk missing path' do
        let(:box_metadata) {
          Hash[
            'disks' => [
              {
                'path' => 'box.img',
              },
              {
                'name' => 'send_box_name',
              },
              {
                'path' => 'box_2.img',
              },
            ],
          ]
        }

        it 'should raise an exception' do
          expect{ subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::BoxFormatMissingAttribute, /: 'disks\[1\]\['path'\]'/)
        end
      end

      context 'with one disk name duplicating a path of another' do
        let(:box_metadata) {
          Hash[
            'disks' => [
              {
                'path' => 'box.img',
                'name' => 'box_2',
              },
              {
                'path' => 'disk.qcow2',
              },
              {
                'path' => 'box_2.img',
              },
            ],
          ]
        }

        it 'should raise an exception' do
          expect{ subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::BoxFormatDuplicateVolume, /test_vagrant_box_image_1.1.1_box_2.img.*'disks\[2\]'.*'disks\[0\]'/)
        end
      end
    end
  end
end
