# frozen_string_literal: true

require_relative '../spec_helper'

describe 'package domain', acceptance: true do
  include_context 'libvirt_acceptance'

  before(:all) do
    expect(Vagrant::Util::Which.which('virt-sysprep')).to be_truthy,
                                                          'packaging tests require virt-sysprep, please install'
    expect(Vagrant::Util::Which.which('virt-sparsify')).to be_truthy,
                                                           'packaging tests require virt-sparsify, please install'

    result = (File.exist?('C:\\') ? `dir /-C #{Dir.tmpdir}` : `df #{Dir.tmpdir}`).split("\n").last
    expect(result.split[3].to_i).to be > 6 * 1024 * 1024,
                                    "packaging tests require more than 6GiB of space under #{Dir.tmpdir}"
  end

  after(:each) do
    assert_execute('vagrant', 'destroy', '--force')
  end

  let(:testbox_envvars) { { VAGRANT_VAGRANTFILE: 'Vagrantfile.testbox' } }

  context 'simple' do
    before do
      environment.skeleton('package_simple')
    end

    after do
      result = environment.execute('vagrant', 'destroy', '--force', extra_env: testbox_envvars)
      expect(result).to exit_with(0)

      assert_execute('vagrant', 'box', 'remove', '--force', 'test-package-simple-domain')
    end

    it 'should succeed' do
      status('Test: machine is created successfully')
      expect(environment.execute('vagrant', 'up')).to exit_with(0)

      status('Test: package machine successfully')
      expect(environment.execute('vagrant', 'package')).to exit_with(0)

      status('Test: add packaged box')
      expect(environment.execute(
        'vagrant', 'box', 'add', '--force', '--name', 'test-package-simple-domain', 'package.box'
      )).to exit_with(0)

      status('Test: machine from packaged box is created successfully')
      result = environment.execute('vagrant', 'up', extra_env: testbox_envvars)
      expect(result).to exit_with(0)
      expect(result.stdout).to match(/test-package-simple-domain/)
    end
  end

  context 'complex' do
    before do
      environment.skeleton('package_complex')
      extra_env.merge!(
        {
          VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS: 'defaults,-ssh-userdir,customize',
          VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS: '--run $(pwd)/scripts/sysprep.sh',
        }
      )
    end

    after do
      expect(environment.execute('vagrant', 'destroy', '--force', extra_env: testbox_envvars)).to exit_with(0)
      assert_execute('vagrant', 'box', 'remove', '--force', 'test-package-complex-domain')
    end

    it 'should succeed' do
      status('Test: machine is created successfully')
      expect(environment.execute('vagrant', 'up')).to exit_with(0)

      status('Test: package machine successfully')
      expect(environment.execute('vagrant', 'package')).to exit_with(0)

      status('Test: add packaged box')
      expect(environment.execute(
        'vagrant', 'box', 'add', '--force', '--name', 'test-package-complex-domain', 'package.box'
      )).to exit_with(0)

      status('Test: machine from packaged box is created successfully')
      result = environment.execute('vagrant', 'up', extra_env: testbox_envvars)
      expect(result).to exit_with(0)
      expect(result.stdout).to match(/test-package-complex-domain/)
    end
  end
end
