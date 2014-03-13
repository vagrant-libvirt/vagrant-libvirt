source 'https://rubygems.org'

# Specify your gem's dependencies in vagrant-libvirt.gemspec
gemspec

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  gem "vagrant", :git => "http://github.com/mitchellh/vagrant.git", :tag => "v1.4.3"
end

group :plugins do
<<<<<<< HEAD
  gem "vagrant-libvirt", :path => '.'
=======
  gem "vagrant-mutate"
>>>>>>> 16ba363... Add support for bridge interface
end

