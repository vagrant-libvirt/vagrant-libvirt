# frozen_string_literal: true

require_relative '../spec_helper'

describe 'handle two disk machine', acceptance: true do
  include_context 'libvirt_acceptance'

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  before do
    environment.skeleton('two_disks')
  end

  it 'should succeed' do
    status('Test: create the machine')
    result = environment.execute('vagrant', 'up')
    expect(result).to exit_with(0)

    status('Test: check disk one is referenced')
    expect(result.stdout).to match(/Image\(vda\):.*work_default.img, virtio, 2G/)

    status('Test: check disk two is referenced')
    expect(result.stdout).to match(/Image\(vdb\):.*work_default_1.img, virtio, 10G/)
  end
end
