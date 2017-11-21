source 'https://rubygems.org'

# Specify your gem's dependencies in vagrant-libvirt.gemspec
gemspec

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  if ENV['VAGRANT_VERSION']
    gem 'vagrant', :git => 'https://github.com/hashicorp/vagrant.git',
      tag: ENV['VAGRANT_VERSION']
  else
    gem 'vagrant', :git => 'https://github.com/hashicorp/vagrant.git'
  end

  gem 'vagrant-spec', :github => 'hashicorp/vagrant-spec'

  gem 'pry'
end

group :plugins do
  gemspec
end

gem 'coveralls', require: false
