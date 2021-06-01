require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant-libvirt/action/clean_machine_folder'

describe VagrantPlugins::ProviderLibvirt::Action::PackageDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'
  include_context 'temporary_dir'

  let(:libvirt_client) { double('libvirt_client') }
  let(:libvirt_domain) { double('libvirt_domain') }
  let(:servers) { double('servers') }
  let(:volumes) { double('volumes') }

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:client).and_return(libvirt_client)
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

        expect(subject.call(env)).to be_nil
        expect(File.exist?(File.join(temp_dir, 'metadata.json'))).to eq(true)
        expect(File.exist?(File.join(temp_dir, 'Vagrantfile'))).to eq(true)
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
