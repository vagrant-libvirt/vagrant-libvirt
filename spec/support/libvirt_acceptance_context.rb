# frozen_string_literal: true

require_relative 'acceptance/context'

FALSEY_VALUES = %w[f false no n 0].freeze

shared_context 'libvirt_acceptance' do
  include_context 'acceptance'

  # The skeleton paths that will be used to configure environments.
  let(:skeleton_paths) do
    root = File.expand_path('../acceptance/support-skeletons', __dir__)
    config.skeleton_paths.dup.unshift(root)
  end

  let(:config) do
    c = VagrantPlugins::VagrantLibvirt::Spec::Acceptance::Configuration.new
    c.clean_on_fail = FALSEY_VALUES.include?(ENV.fetch('VAGRANT_SPEC_SKIP_CLEANUP', 'false').to_s.downcase)

    c
  end

  before(:each) do
    vagrant_home = ENV.fetch('VAGRANT_HOME', File.expand_path('~/.vagrant.d'))
    # allow execution environment to cache boxes used
    symlink_boxes(vagrant_home, environment)
    copy_vagrantfile(vagrant_home, environment)
  end

  after(:each) do
    # ensure we remove the symlink
    boxes_symlink = File.join(environment.homedir, 'boxes')
    File.delete(boxes_symlink) if File.symlink?(boxes_symlink)
  end

  around do |example|
    vagrant_cwd = ENV.delete('VAGRANT_CWD')
    env_provider_before = ENV.fetch('VAGRANT_DEFAULT_PROVIDER', nil)
    ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'

    begin
      example.run
    ensure
      ENV['VAGRANT_CWD'] = vagrant_cwd if vagrant_cwd
      if env_provider_before.nil?
        ENV.delete('VAGRANT_DEFAULT_PROVIDER')
      else
        ENV['VAGRANT_DEFAULT_PROVIDER'] = env_provider_before
      end
    end
  end

  def duplicate_environment(env, *args)
    dup_env = new_environment(*args)
    symlink_boxes(env.homedir, dup_env)
    copy_vagrantfile(vagrant_home, environment)

    dup_env
  end

  def symlink_boxes(vagrant_home, target_env)
    return if vagrant_home.nil?

    # allow use the same boxes location as source environment
    File.symlink File.realpath(File.join(vagrant_home, 'boxes')), File.join(target_env.homedir, 'boxes')
  end

  def copy_vagrantfile(vagrant_home, target_env)
    return if vagrant_home.nil?

    # allows for a helper Vagrantfile to force specific provider options if testing
    # environment needs them
    vagrantfile = File.join(vagrant_home, 'Vagrantfile')
    if File.exist?(vagrantfile) and !File.exist?(File.join(target_env.homedir, 'Vagrantfile'))
      FileUtils.cp(vagrantfile, target_env.homedir)
    end
  end
end
