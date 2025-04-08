# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/action/package_domain'

describe VagrantPlugins::ProviderLibvirt::Action::PackageDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'
  include_context 'temporary_dir'

  let(:servers) { double('servers') }
  let(:volumes) { double('volumes') }
  let(:metadata_file) { double('file') }
  let(:vagrantfile_file) { double('file') }

  describe '#call' do
    before do
      allow(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)

      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)

      allow(connection).to receive(:volumes).and_return(volumes)

      allow(logger).to receive(:info)

      env["package.directory"] = temp_dir
    end

    context 'with defaults' do
      let(:root_disk) { double('libvirt_domain_disk') }
      before do
        allow(root_disk).to receive(:name).and_return('default_domain.img')
        allow(domain).to receive(:volumes).and_return([root_disk])
        allow(libvirt_domain).to receive(:name).and_return('default_domain')
        allow(subject).to receive(:download_image).and_return(true)
      end

      it 'should succeed' do
        expect(ui).to receive(:info).with('Packaging domain...')
        expect(ui).to receive(:info).with(/Downloading default_domain.img to .*\/box.img/)
        expect(ui).to receive(:info).with('Image has backing image, copying image and rebasing ...')
        expect(subject).to receive(:`).with(/qemu-img info .*\/box.img | grep 'backing file:' | cut -d ':' -f2/).and_return("some image")
        expect(subject).to receive(:`).with(/qemu-img rebase -p -b "" .*\/box.img/)
        expect(subject).to receive(:`).with(/virt-sysprep --no-logfile --operations .* -a .*\/box.img .*/)
        expect(subject).to receive(:`).with(/virt-sparsify --in-place .*\/box.img/)
        expect(subject).to receive(:`).with(/qemu-img info --output=json .*\/box.img/).and_return(
          { 'virtual-size': 5*1024*1024*1024 }.to_json
        )
        expect(File).to receive(:write).with(
          /.*\/metadata.json/,
          <<-EOF.unindent
          {
            "provider": "libvirt",
            "format": "qcow2",
            "virtual_size": 5
          }
          EOF
        )
        expect(File).to receive(:write).with(/.*\/Vagrantfile/, /.*/)

        expect(subject.call(env)).to be_nil
      end
    end

    context 'with nil volume' do
      let(:root_disk) { double('libvirt_domain_disk') }
      before do
        allow(root_disk).to receive(:name).and_return('default_domain.img')
        allow(domain).to receive(:volumes).and_return([nil, root_disk])
        allow(libvirt_domain).to receive(:name).and_return('default_domain')
        allow(subject).to receive(:download_image).and_return(true)
      end

      it 'should succeed' do
        expect(ui).to receive(:info).with('Packaging domain...')
        expect(ui).to receive(:info).with(/Downloading default_domain.img to .*\/box.img/)
        expect(ui).to receive(:info).with('Image has backing image, copying image and rebasing ...')
        expect(subject).to receive(:`).with(/qemu-img info .*\/box.img | grep 'backing file:' | cut -d ':' -f2/).and_return("some image")
        expect(subject).to receive(:`).with(/qemu-img rebase -p -b "" .*\/box.img/)
        expect(subject).to receive(:`).with(/virt-sysprep --no-logfile --operations .* -a .*\/box.img .*/)
        expect(subject).to receive(:`).with(/virt-sparsify --in-place .*\/box.img/)
        expect(subject).to receive(:`).with(/qemu-img info --output=json .*\/box.img/).and_return(
          { 'virtual-size': 5*1024*1024*1024 }.to_json
        )

        expect(subject.call(env)).to be_nil
      end
    end

    context 'when detecting the format' do
      let(:root_disk) { double('libvirt_domain_disk') }
      let(:disk2) { double('libvirt_additional_disk') }
      let(:fake_env) { Hash.new }

      before do
        allow(root_disk).to receive(:name).and_return('default_domain.img')
        allow(disk2).to receive(:name).and_return('disk2.img')
        allow(libvirt_domain).to receive(:name).and_return('default_domain')
      end

      context 'with two disks' do
        before do
          allow(domain).to receive(:volumes).and_return([root_disk, disk2])
        end

        it 'should emit a warning' do
          expect(ui).to receive(:info).with('Packaging domain...')
          expect(ui).to receive(:warn).with(/Detected more than one volume for machine.*\n.*/)
          expect(subject).to receive(:package_v1)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'with format set to v1' do
        before do
          allow(domain).to receive(:volumes).and_return([root_disk])
          stub_const("ENV", fake_env)
          fake_env['VAGRANT_LIBVIRT_BOX_FORMAT_VERSION'] = "v1"
        end

        it 'should call v1 packaging' do
          expect(ui).to receive(:info).with('Packaging domain...')
          expect(subject).to receive(:package_v1)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'with format set to v2' do
        before do
          allow(domain).to receive(:volumes).and_return([root_disk])
          stub_const("ENV", fake_env)
          fake_env['VAGRANT_LIBVIRT_BOX_FORMAT_VERSION'] = "v2"
        end

        it 'should call v1 packaging' do
          expect(ui).to receive(:info).with('Packaging domain...')
          expect(subject).to receive(:package_v2)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'with invalid format' do
        before do
          allow(domain).to receive(:volumes).and_return([root_disk])
          stub_const("ENV", fake_env)
          fake_env['VAGRANT_LIBVIRT_BOX_FORMAT_VERSION'] = "bad format"
        end

        it 'should emit a warning and default to v1' do
          expect(ui).to receive(:info).with('Packaging domain...')
          expect(ui).to receive(:warn).with(/Unrecognized value for.*defaulting to v1/)
          expect(subject).to receive(:package_v1)

          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'with v2 format' do
      let(:disk1) { double('libvirt_domain_disk') }
      let(:disk2) { double('libvirt_additional_disk') }
      let(:fake_env) { Hash.new }

      before do
        allow(disk1).to receive(:name).and_return('default_domain.img')
        allow(disk2).to receive(:name).and_return('disk2.img')
        allow(libvirt_domain).to receive(:name).and_return('default_domain')
        allow(subject).to receive(:download_image).and_return(true).twice()

        stub_const("ENV", fake_env)
        fake_env['VAGRANT_LIBVIRT_BOX_FORMAT_VERSION'] = "v2"
      end

      context 'with 2 disks' do
        before do
          allow(domain).to receive(:volumes).and_return([disk1, disk2])
        end

        it 'should succeed' do
          expect(ui).to receive(:info).with('Packaging domain...')
          expect(ui).to receive(:info).with(/Downloading default_domain.img to .*\/box_1.img/)
          expect(ui).to receive(:info).with('Image has backing image, copying image and rebasing ...')
          expect(subject).to receive(:`).with(/qemu-img info .*\/box_1.img | grep 'backing file:' | cut -d ':' -f2/).and_return("some image")
          expect(subject).to receive(:`).with(/qemu-img rebase -p -b "" .*\/box_1.img/)
          expect(subject).to receive(:`).with(/virt-sysprep --no-logfile --operations .* -a .*\/box_1.img .*/)
          expect(subject).to receive(:`).with(/virt-sparsify --in-place .*\/box_1.img/)
          expect(ui).to receive(:info).with(/Downloading disk2.img to .*\/box_2.img/)
          expect(ui).to receive(:info).with('Image has backing image, copying image and rebasing ...')
          expect(subject).to receive(:`).with(/qemu-img info .*\/box_2.img | grep 'backing file:' | cut -d ':' -f2/).and_return("some image")
          expect(subject).to receive(:`).with(/qemu-img rebase -p -b "" .*\/box_2.img/)
          expect(subject).to receive(:`).with(/virt-sparsify --in-place .*\/box_2.img/)

          expect(File).to receive(:write).with(
            /.*\/metadata.json/,
            <<-EOF.unindent.rstrip()
            {
              "provider": "libvirt",
              "format": "qcow2",
              "disks": [
                {
                  "path": "box_1.img"
                },
                {
                  "path": "box_2.img"
                }
              ]
            }
            EOF
          )
          expect(File).to receive(:write).with(/.*\/Vagrantfile/, /.*/)

          expect(subject.call(env)).to be_nil
        end
      end

      context 'with 1 disk' do
        before do
          allow(domain).to receive(:volumes).and_return([disk1])
        end

        it 'should succeed' do
          expect(ui).to receive(:info).with('Packaging domain...')
          expect(ui).to receive(:info).with(/Downloading default_domain.img to .*\/box_1.img/)
          expect(ui).to receive(:info).with('Image has backing image, copying image and rebasing ...')
          expect(subject).to receive(:`).with(/qemu-img info .*\/box_1.img | grep 'backing file:' | cut -d ':' -f2/).and_return("some image")
          expect(subject).to receive(:`).with(/qemu-img rebase -p -b "" .*\/box_1.img/)
          expect(subject).to receive(:`).with(/virt-sysprep --no-logfile --operations .* -a .*\/box_1.img .*/)
          expect(subject).to receive(:`).with(/virt-sparsify --in-place .*\/box_1.img/)

          expect(File).to receive(:write).with(
            /.*\/metadata.json/,
            <<-EOF.unindent.rstrip()
            {
              "provider": "libvirt",
              "format": "qcow2",
              "disks": [
                {
                  "path": "box_1.img"
                }
              ]
            }
            EOF
          )
          expect(File).to receive(:write).with(/.*\/Vagrantfile/, /.*/)

          expect(subject.call(env)).to be_nil
        end
      end
    end
  end

  describe '#vagrantfile_content' do
    context 'with defaults' do
      it 'should output expected content' do
        expect(subject.vagrantfile_content(env)).to eq(
          <<-EOF.unindent
          Vagrant.configure("2") do |config|
            config.vm.provider :libvirt do |libvirt|
              libvirt.driver = "kvm"
            end

          end
          EOF
        )
      end
    end

    context 'with custom user vagrantfile' do
      before do
        env["package.vagrantfile"] = "_Vagrantfile"
      end
      it 'should output Vagrantfile containing reference' do
        expect(subject.vagrantfile_content(env)).to eq(
          <<-EOF.unindent
          Vagrant.configure("2") do |config|
            config.vm.provider :libvirt do |libvirt|
              libvirt.driver = "kvm"
            end

            # Load include vagrant file if it exists after the auto-generated
            # so it can override any of the settings
            include_vagrantfile = File.expand_path("../include/_Vagrantfile", __FILE__)
            load include_vagrantfile if File.exist?(include_vagrantfile)

          end
          EOF
        )
      end
    end
  end
end
