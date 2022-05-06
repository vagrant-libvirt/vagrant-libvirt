# frozen_string_literal: true

source 'https://rubygems.org'

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  vagrant_version = ENV['VAGRANT_VERSION']
  if !vagrant_version.nil? && !vagrant_version.empty?
    gem 'vagrant', :git => 'https://github.com/hashicorp/vagrant.git',
      :ref => vagrant_version
  else
    gem 'vagrant', :git => 'https://github.com/hashicorp/vagrant.git',
      :branch => 'main'
  end

  begin
    raise if vagrant_version.empty?
    vagrant_version = vagrant_version[1..-1] if vagrant_version && vagrant_version.start_with?('v')
    vagrant_gem_version = Gem::Version.new(vagrant_version)
  rescue
    # default to newer if unable to parse
    vagrant_gem_version = Gem::Version.new('2.2.8')
  end

  vagrant_spec_verison = ENV['VAGRANT_SPEC_VERSION']
  if !vagrant_spec_verison.nil? && !vagrant_spec_verison.empty?
    gem 'vagrant-spec', :git => 'https://github.com/hashicorp/vagrant-spec', :ref => vagrant_spec_verison
  elsif vagrant_gem_version <= Gem::Version.new('2.2.7')
    gem 'vagrant-spec', :git => 'https://github.com/hashicorp/vagrant-spec', :ref => '161128f2216cee8edb7bcd30da18bd4dea86f98a'
  else
    gem 'vagrant-spec', :git => 'https://github.com/hashicorp/vagrant-spec', :branch => "main"
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    gem 'rexml'
  end

  gem 'pry'
  gem 'simplecov'
  gem 'simplecov-lcov'
end

group :plugins do
  gemspec
end
