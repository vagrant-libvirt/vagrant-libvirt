# frozen_string_literal: true

require_relative '../spec_helper'

describe 'simple vm provision via shell', acceptance: true do
  include_context 'libvirt_acceptance'

  before do
    environment.skeleton('simple_vm_provision')
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should succeed' do
    status('Test: machine is created successfully')
    result = environment.execute('vagrant', 'up')
    expect(result).to exit_with(0)

    status('Test: provision script executed')
    expect(result.stdout).to match(/Hello, World/)

    status('Test: reload')
    result = environment.execute('vagrant', 'reload')
    expect(result).to exit_with(0)

    status('Test: provision checked if already executed')
    expect(result.stdout).to match(/Machine already provisioned/)
  end
end
