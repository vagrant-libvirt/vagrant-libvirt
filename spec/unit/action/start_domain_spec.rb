require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/action/start_domain'

describe VagrantPlugins::ProviderLibvirt::Action::StartDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:libvirt_domain) { double('libvirt_domain') }
  let(:libvirt_client) { double('libvirt_client') }
  let(:servers) { double('servers') }

  let(:domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), test_file)) }

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:client).and_return(libvirt_client)
      allow(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)

      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)
    end

    context 'default config' do
      let(:test_file) { 'default.xml' }

      before do
        allow(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)

        allow(libvirt_domain).to receive(:max_memory).and_return(512*1024)
        allow(libvirt_domain).to receive(:num_vcpus).and_return(1)
      end

      it 'should execute correctly' do
        expect(libvirt_domain).to receive(:autostart=)
        expect(domain).to receive(:start)

        expect(subject.call(env)).to be_nil
      end
    end
  end
end
