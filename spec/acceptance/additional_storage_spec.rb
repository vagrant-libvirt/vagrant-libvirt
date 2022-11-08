# frozen_string_literal: true

require_relative '../spec_helper'

describe 'additional storage configured', acceptance: true do
  include_context 'libvirt_acceptance'

  before do
    environment.skeleton('additional_storage')
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should succeed' do
    status('Test: machine is created successfully')
    result = environment.execute('vagrant', 'up')
    expect(result).to exit_with(0)

    status('Test: additional storage configured')
    expect(result.stdout).to match(/\(vda\).*work_default.img/)
    expect(result.stdout).to match(/\(vdb\).*work_default-vdb\.qcow2/)

    status('Test: reload handles additional storage correctly')
    result = environment.execute('vagrant', 'reload')
    expect(result).to exit_with(0)

    status('Test: additional storage reported correctly')
    expect(result.stdout).to match(/\(vdb\).*work_default-vdb\.qcow2/)
  end
end
