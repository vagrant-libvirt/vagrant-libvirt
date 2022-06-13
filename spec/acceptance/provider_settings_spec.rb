# frozen_string_literal: true

require 'spec_helper'

describe 'provider settings', acceptance: true do
  include_context 'libvirt_acceptance'

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  context 'with defaults' do
    before do
      environment.skeleton('default_settings')
    end

    it 'should succeed' do
      status('Test: machine is created successfully')
      result = environment.execute('vagrant', 'up')
      expect(result).to exit_with(0)

      status('Test: CPU matches default')
      expect(result.stdout).to match(/Cpus:\s+1$/)

      status('Test: memory matches default')
      expect(result.stdout).to match(/Memory:\s+512M/)

      status('Test: default prefix is used')
      expect(result.stdout).to match(/Name:\s+work_default$/)
    end
  end

  context 'with modified config' do
    before do
      environment.skeleton('adjusted_settings')
    end

    it 'should succeed' do
      status('Test: machine is created successfully')
      result = environment.execute('vagrant', 'up')
      expect(result).to exit_with(0)

      status('Test: CPUs are changed')
      expect(result.stdout).to match(/Cpus:\s+2$/)

      status('Test: memory is changed')
      expect(result.stdout).to match(/Memory:\s+1000M$/)

      status('Test: default prefix is changed')
      expect(result.stdout).to match(/Name:\s+changed_default_prefixdefault$/)
      expect(result.stdout).to match(/\(vda\).*changed_default_prefixdefault\.img/)
    end
  end
end
