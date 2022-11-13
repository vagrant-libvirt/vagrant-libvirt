# frozen_string_literal: true

require_relative '../spec_helper'

describe 'package domain', acceptance: true do
  include_context 'libvirt_acceptance'

  before(:all) do
    expect(Vagrant::Util::Which.which('virsh')).to be_truthy,
                                                          'networking tests require virsh, please install'
    expect(system('virsh --connect=qemu:///system uri >/dev/null')).to be_truthy,
      'network tests require access to qemu:///system context, please ensure test user has correct permissions'
  end

  after(:each) do
    assert_execute('vagrant', 'destroy', '--force')
  end

  before do
    environment.skeleton('network_no_autostart')
  end

  context 'when host is rebooted' do
    before do
      result = environment.execute('vagrant', 'up')
      expect(result).to exit_with(0)

      result = environment.execute('vagrant', 'halt')
      expect(result).to exit_with(0)

      result = environment.execute('virsh', '--connect=qemu:///system', 'net-destroy', 'vagrant-libvirt-test')
      expect(result).to exit_with(0)
    end

    it 'should start networking on restart' do
      status('Test: machine restarts networking')
      result = environment.execute('vagrant', 'up')
      expect(result).to exit_with(0)
    end
  end
end
