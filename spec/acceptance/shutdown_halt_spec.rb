# frozen_string_literal: true

require_relative '../spec_helper'

describe 'shutdown and halt', acceptance: true do
  include_context 'libvirt_acceptance'

  before do
    environment.skeleton('default_settings')
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  context 'when system accessible' do
    it 'graceful shutdown should succeed' do
      status('Test: machine is created successfully')
      result = environment.execute('vagrant', 'up')
      expect(result).to exit_with(0)

      status('Test: Halt')
      result = environment.execute('vagrant', 'halt')
      expect(result).to exit_with(0)

      status('Test: validate output')
      expect(result.stdout).to match(/Attempting graceful shutdown of VM/)
      expect(result.stdout).to_not match(/Halting domain.../)
    end

    it 'forced halt should skip graceful and succeed' do
      status('Test: machine is created successfully')
      result = environment.execute('vagrant', 'up')
      expect(result).to exit_with(0)

      status('Test: Halt')
      result = environment.execute('vagrant', 'halt', '-f')
      expect(result).to exit_with(0)

      status('Test: validate output')
      expect(result.stdout).to_not match(/Attempting graceful shutdown of VM/)
      expect(result.stdout).to match(/Halting domain.../)
    end
  end

  context 'when system hung' do
    it 'should call halt after failed graceful' do
      status('Test: machine is created successfully')
      result = environment.execute('vagrant', 'up')
      expect(result).to exit_with(0)

      status('Test: Trigger crash to prevent graceful halt working')
      result = environment.execute('vagrant', 'ssh', '-c', 'nohup sudo sh -c \'echo -n c > /proc/sysrq-trigger\' >/dev/null 2>&1 </dev/null', '--', '-f')
      expect(result).to exit_with(0)

      status('Test: Halt')
      result = environment.execute('vagrant', 'halt')
      expect(result).to exit_with(0)

      status('Test: validate output')
      expect(result.stdout).to match(/Attempting graceful shutdown of VM/)
      expect(result.stdout).to match(/Guest communication could not be established/)
      expect(result.stdout).to match(/Halting domain.../)
    end
  end
end
