source 'https://rubygems.org'

# Specify your gem's dependencies in vagrant-libvirt.gemspec
gemspec

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  vagrant_version = ENV['VAGRANT_VERSION']
  if vagrant_version
    gem 'vagrant', :git => 'https://github.com/hashicorp/vagrant.git',
      tag: vagrant_version
  else
    gem 'vagrant', :git => 'https://github.com/hashicorp/vagrant.git'
  end

  begin
    raise if vagrant_version.empty?
    vagrant_version = vagrant_version[1..-1] if vagrant_version && vagrant_version.start_with?('v')
    vagrant_gem_version = Gem::Version.new(vagrant_version)
  rescue
    # default to newer if unable to parse
    vagrant_gem_version = Gem::Version.new('2.2.8')
  end

  if vagrant_gem_version <= Gem::Version.new('2.2.7')
    gem 'vagrant-spec', :github => 'hashicorp/vagrant-spec', :ref => '161128f2216cee8edb7bcd30da18bd4dea86f98a'
  else
    gem 'vagrant-spec', :github => 'hashicorp/vagrant-spec', :branch => "main"
  end

  gem 'pry'
end

group :plugins do
  gemspec
end

gem 'coveralls', require: false
