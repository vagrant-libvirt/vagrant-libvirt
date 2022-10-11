# frozen_string_literal: true

require 'spec_helper'

require 'vagrant-libvirt/action/set_boot_order'

describe VagrantPlugins::ProviderLibvirt::Action::SetBootOrder do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  #before do
  #  allow(driver).to receive(:created?).and_return(true)
  #end

  describe '#call' do
    it 'should return early' do
      expect(connection).to_not receive(:client)

      expect(subject.call(env)).to be_nil
    end

    context 'with boot_order defined' do
      let(:domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), test_file)) }
      let(:updated_domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), updated_test_file)) }
      let(:test_file) { 'default.xml' }
      let(:updated_test_file) { 'explicit_boot_order.xml' }
      let(:vagrantfile_providerconfig) do
        <<-EOF
        libvirt.boot "hd"
        libvirt.boot "cdrom"
        libvirt.boot "network" => 'vagrant-libvirt'
        EOF
      end

      before do
        allow(connection).to receive(:client).and_return(libvirt_client)
        allow(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)
        allow(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)
        allow(logger).to receive(:debug)
      end

      it 'should configure the boot order' do
        expect(libvirt_client).to receive(:define_domain_xml).with(updated_domain_xml)
        expect(subject.call(env)).to be_nil
      end

      context 'with multiple networks in bootorder' do
        let(:vagrantfile_providerconfig) do
          <<-EOF
          libvirt.boot "hd"
          libvirt.boot "cdrom"
          libvirt.boot "network" => 'vagrant-libvirt'
          libvirt.boot "network" => 'vagrant-libvirt'
          EOF
        end

        it 'should raise an exception' do
          expect { subject.call(env) }.to raise_error('Defined only for 1 network for boot')
        end
      end
    end
  end
end
