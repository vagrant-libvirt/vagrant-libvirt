# frozen_string_literal: true

require_relative '../spec_helper'

describe 'snapshots', acceptance: true do
  include_context 'libvirt_acceptance'

  after(:each) do
    assert_execute('vagrant', 'destroy', '--force')
  end

  before do
    environment.skeleton('snapshots')
  end

  it 'should succeed' do
    status('Test: machine is created successfully')
    expect(environment.execute('vagrant', 'up')).to exit_with(0)

    status('Test: add test file')
    expect(environment.execute('vagrant', 'ssh', '--', '-t', 'touch a.txt')).to exit_with(0)

    status('Test: create snapshot')
    expect(environment.execute('vagrant', 'snapshot', 'save', 'default', 'test')).to exit_with(0)

    status('Test: modify files')
    expect(environment.execute('vagrant', 'ssh', '--', '-t', 'rm a.txt')).to exit_with(0)
    expect(environment.execute('vagrant', 'ssh', '--', '-t', 'ls a.txt')).to exit_with(1)
    expect(environment.execute('vagrant', 'ssh', '--', '-t', 'touch b.txt')).to exit_with(0)

    status('Test: restore snapshot')
    expect(environment.execute('vagrant', 'snapshot', 'restore', 'test')).to exit_with(0)

    # KVM needs a moment for IO to catch up.
    # If anyone comes up with a better way to wait, please update this.
    sleep(3)

    status('Test: files are as expected')
    expect(environment.execute('vagrant', 'ssh', '--', '-t', 'ls a.txt')).to exit_with(0)
    expect(environment.execute('vagrant', 'ssh', '--', '-t', 'ls b.txt')).to exit_with(1)

    status('Test: snapshot removal works')
    expect(environment.execute('vagrant', 'snapshot', 'delete', 'test')).to exit_with(0)
  end
end
