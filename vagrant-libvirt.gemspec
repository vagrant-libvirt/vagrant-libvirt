# -*- encoding: utf-8 -*-
require File.expand_path('../lib/vagrant-libvirt/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Lukas Stanek','Dima Vasilets','Brian Pitts']
  gem.email         = ['ls@elostech.cz','pronix.service@gmail.com','brian@polibyte.com']
  gem.license       = 'MIT'
  gem.description   = %q{libvirt provider for Vagrant.}
  gem.summary       = %q{libvirt provider for Vagrant.}
  gem.homepage      = 'https://github.com/vagrant-libvirt/vagrant-libvirt'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'vagrant-libvirt'
  gem.require_paths = ['lib']
  gem.version       = VagrantPlugins::ProviderLibvirt::VERSION

  gem.add_development_dependency "rspec-core", "~> 2.14.0"
  gem.add_development_dependency "rspec-expectations", "~> 2.14.0"
  gem.add_development_dependency "rspec-mocks", "~> 2.14.0"

  gem.add_runtime_dependency 'fog-libvirt', '>= 0.3.0'
  gem.add_runtime_dependency 'nokogiri', '~> 1.6.0'

  gem.add_development_dependency 'rake'
end
