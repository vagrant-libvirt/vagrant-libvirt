require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/action/create_domain'

describe VagrantPlugins::ProviderLibvirt::Action::CreateDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:libvirt_client) { double('libvirt_client') }
  let(:servers) { double('servers') }
  let(:volumes) { double('volumes') }

  let(:storage_pool_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), test_file)) }
  let(:libvirt_storage_pool) { double('storage_pool') }

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:client).and_return(libvirt_client)

      allow(connection).to receive(:servers).and_return(servers)
      allow(connection).to receive(:volumes).and_return(volumes)
    end

    context 'default pool' do
      let(:test_file) { 'default_storage_pool.xml' }

      it 'should execute correctly' do
        expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(libvirt_storage_pool)
        expect(libvirt_storage_pool).to receive(:xml_desc).and_return(storage_pool_xml)
        expect(servers).to receive(:create).and_return(machine)

        expect(subject.call(env)).to be_nil
      end

      context 'additional disks' do
        let(:vagrantfile) do
          <<-EOF
          Vagrant.configure('2') do |config|
            config.vm.define :test
            config.vm.provider :libvirt do |libvirt|
              libvirt.storage :file, :size => '20G'
            end
          end
          EOF
        end

        context 'volume create failed' do
          it 'should raise an exception' do
            expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(libvirt_storage_pool)
            expect(libvirt_storage_pool).to receive(:xml_desc).and_return(storage_pool_xml)
            expect(volumes).to receive(:create).and_raise(Libvirt::Error)

            expect{ subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::FogCreateDomainVolumeError)
          end
        end

        context 'volume create succeeded' do
          it 'should complete' do
            expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(libvirt_storage_pool)
            expect(libvirt_storage_pool).to receive(:xml_desc).and_return(storage_pool_xml)
            expect(volumes).to receive(:create)
            expect(servers).to receive(:create).and_return(machine)

            expect(subject.call(env)).to be_nil
          end
        end
      end
    end

    context 'no default pool' do
      it 'should raise an exception' do
        expect(libvirt_client).to receive(:lookup_storage_pool_by_name).and_return(nil)

        expect{ subject.call(env) }.to raise_error(VagrantPlugins::ProviderLibvirt::Errors::NoStoragePool)
      end
    end
  end
end
