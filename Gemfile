source 'https://rubygems.org'

# Specify your gem's dependencies in vagrant-libvirt.gemspec
gemspec

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  gem "vagrant", :git => "https://github.com/mafigit/vagrant.git", :branch => "v1.4.3-my"
end

group :plugins do
  gem "vagrant-libvirt", :path => '.'
  gem "vagrant-mutate"
end

