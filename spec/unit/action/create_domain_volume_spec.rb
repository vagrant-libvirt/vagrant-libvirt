require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'

require 'vagrant-libvirt/action/destroy_domain'

describe VagrantPlugins::ProviderLibvirt::Action::CreateDomainVolume do
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

  describe '#call' do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver)
        .to receive(:connection).and_return(connection)
      allow(connection).to receive(:client).and_return(libvirt_client)
      allow(connection).to receive(:volumes).and_return(volumes)
      allow(volumes).to receive(:all).and_return(all)
      allow(all).to receive(:first).and_return(box_volume)
      allow(box_volume).to receive(:id).and_return(nil)
      env[:domain_name] = 'test'

    end
    context 'When has one disk' do
      before do
        allow(box_volume).to receive(:path).and_return('/test/path_0.img')
        env[:box_volumes] = [
          {
            :name=>"test_vagrant_box_image_1.1.1_0.img",
            :virtual_size=>5
          }
        ]
      end

      it 'we must have one disk in env' do
        expected_xml =
"""<volume>
  <name>test.img</name>
  <capacity unit=\"G\">5</capacity>
  <target>
    <format type=\"qcow2\"></format>
    <permissions>
      <owner>0</owner>
      <group>0</group>
      <label>virt_image_t</label>
    </permissions>
  </target>
  <backingStore>
    <path>/test/path_0.img</path>
    <format type=\"qcow2\"></format>
    <permissions>
      <owner>0</owner>
      <group>0</group>
      <label>virt_image_t</label>
    </permissions>
  </backingStore>
</volume>
"""
        expect(ui).to receive(:info).with('Creating image (snapshot of base box volume).')
        expect(logger).to receive(:debug).with('Using pool default for base box snapshot')
        expect(volumes).to receive(:create).with(
          :xml => expected_xml,
          :pool_name => "default"
        )
        expect(subject.call(env)).to be_nil
      end
    end
    context 'When has three disk' do
      before do
        allow(box_volume).to receive(:path).and_return(
          '/test/path_0.img',
          '/test/path_1.img',
          '/test/path_2.img',
        )
        env[:box_volumes] = [
          {
            :name=>"test_vagrant_box_image_1.1.1_0.img",
            :virtual_size=>5
          },
          {
            :name=>"test_vagrant_box_image_1.1.1_1.img",
            :virtual_size=>10
          },
          {
            :name=>"test_vagrant_box_image_1.1.1_2.img",
            :virtual_size=>20
          }
        ]
      end

      it 'we must have three disks in env' do
        expected_xml_0 =
"""<volume>
  <name>test.img</name>
  <capacity unit=\"G\">5</capacity>
  <target>
    <format type=\"qcow2\"></format>
    <permissions>
      <owner>0</owner>
      <group>0</group>
      <label>virt_image_t</label>
    </permissions>
  </target>
  <backingStore>
    <path>/test/path_0.img</path>
    <format type=\"qcow2\"></format>
    <permissions>
      <owner>0</owner>
      <group>0</group>
      <label>virt_image_t</label>
    </permissions>
  </backingStore>
</volume>
"""
expected_xml_1 = 
"""<volume>
  <name>test_1.img</name>
  <capacity unit=\"G\">10</capacity>
  <target>
    <format type=\"qcow2\"></format>
    <permissions>
      <owner>0</owner>
      <group>0</group>
      <label>virt_image_t</label>
    </permissions>
  </target>
  <backingStore>
    <path>/test/path_1.img</path>
    <format type=\"qcow2\"></format>
    <permissions>
      <owner>0</owner>
      <group>0</group>
      <label>virt_image_t</label>
    </permissions>
  </backingStore>
</volume>
"""
expected_xml_2 = 
"""<volume>
  <name>test_2.img</name>
  <capacity unit=\"G\">20</capacity>
  <target>
    <format type=\"qcow2\"></format>
    <permissions>
      <owner>0</owner>
      <group>0</group>
      <label>virt_image_t</label>
    </permissions>
  </target>
  <backingStore>
    <path>/test/path_2.img</path>
    <format type=\"qcow2\"></format>
    <permissions>
      <owner>0</owner>
      <group>0</group>
      <label>virt_image_t</label>
    </permissions>
  </backingStore>
</volume>
"""
        expect(ui).to receive(:info).with('Creating image (snapshot of base box volume).')
        expect(logger).to receive(:debug).with('Using pool default for base box snapshot')
        expect(volumes).to receive(:create).with(
          :xml => expected_xml_0,
          :pool_name => "default"
        )
        expect(logger).to receive(:debug).with('Using pool default for base box snapshot')
        expect(volumes).to receive(:create).with(
          :xml => expected_xml_1,
          :pool_name => "default"
        )
        expect(logger).to receive(:debug).with('Using pool default for base box snapshot')
        expect(volumes).to receive(:create).with(
          :xml => expected_xml_2,
          :pool_name => "default"
        )
        expect(subject.call(env)).to be_nil

      end
    end
  end
end
