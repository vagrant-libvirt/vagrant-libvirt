# frozen_string_literal: true

require_relative '../spec_helper'

require 'vagrant-libvirt'
require 'vagrant-libvirt/plugin'
require 'vagrant-libvirt/action'
require 'vagrant-libvirt/action/remove_libvirt_image'


describe VagrantPlugins::ProviderLibvirt::Plugin do
  subject { described_class.new }

  include_context 'unit'

  describe '#action_hook remove_libvirt_image' do
    before do
      # set up some dummy boxes
      box_path = File.join(env[:env].boxes.directory, 'vagrant-libvirt-VAGRANTSLASH-test', '0.0.1')
      ['libvirt', 'virtualbox'].each do |provider|
        provider_path = File.join(box_path, provider)
        FileUtils.mkdir_p(provider_path)
        metadata = {'provider': provider}
        File.open(File.join(provider_path, 'metadata.json'), "w") { |f| f.write metadata.to_json }
      end
    end

    it 'should call the action hook after box remove' do
      expect_any_instance_of(VagrantPlugins::ProviderLibvirt::Action::RemoveLibvirtImage).to receive(:call) do |cls, env|
        cls.instance_variable_get(:@app).call(env)
      end
      expect {
        env[:env].action_runner.run(
          Vagrant::Action.action_box_remove, {
            box_name: 'vagrant-libvirt/test',
            box_provider: 'libvirt',
            box_version: '0.0.1',
            force_confirm_box_remove: true,
            box_remove_all_versions: false,
            ui: ui,
          }
        )
      }.to_not raise_error
    end
  end
end
