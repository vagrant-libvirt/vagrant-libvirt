# frozen_string_literal: true

require_relative '../spec_helper'

describe 'handle two disk machine', acceptance: true do
  include_context 'libvirt_acceptance'

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  before do
    environment.skeleton('two_disks')
    environment.execute(File.expand_path('../../tools/create_box_with_two_disks.sh', __dir__),
                        environment.homedir.to_s, 'vagrant')
  end

  it 'should succeed' do
    status('Test: machine is created successfully')
    result = environment.execute('vagrant', 'up')
    expect(result).to exit_with(0)

    status('Test: disk one referenced')
    expect(result.stdout).to match(/Image\(vda\):.*work_default.img, virtio, 2G/)

    status('Test: disk two referenced')
    expect(result.stdout).to match(/Image\(vdb\):.*work_default_1.img, virtio, 10G/)
  end
end
