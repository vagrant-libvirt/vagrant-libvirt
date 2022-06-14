# frozen_string_literal: true

require 'spec_helper'

describe 'use qemu agent to determine machine private address', acceptance: true do
  include_context 'libvirt_acceptance'

  before do
    environment.skeleton('qemu_agent')
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should succeed' do
    status('Test: machine is created successfully')
    result = environment.execute('vagrant', 'up')
    expect(result).to exit_with(0)

    # extract SSH IP address emitted as it should be the private network since
    # the mgmt network has not been attached
    hostname = result.stdout.each_line.find { |line| line.include?('SSH address:') }
    expect(hostname).to_not be_nil
    ip_address = hostname.strip.split.last.split(':').first
    # default private network for vagrant-libvirt unless explicitly configured
    expect(IPAddr.new('172.28.128.0/255.255.255.0')).to include(IPAddr.new(ip_address))

    # ssh'ing successfully means that the private network is accessible
    status('Test: machine private network is accessible')
    result = environment.execute('vagrant', 'ssh', '-c', 'echo "hello, world"')
    expect(result).to exit_with(0)
    expect(result.stdout).to match(/hello, world/)
  end
end
