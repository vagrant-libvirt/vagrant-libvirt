# -*- encoding: utf-8 -*-
require File.expand_path('../lib/vagrant-libvirt/version', __FILE__)

Gem::Specification.new do |s|
  s.authors       = ['Lukas Stanek','Dima Vasilets','Brian Pitts']
  s.email         = ['ls@elostech.cz','pronix.service@gmail.com','brian@polibyte.com']
  s.license       = 'MIT'
  s.description   = %q{libvirt provider for Vagrant.}
  s.summary       = %q{libvirt provider for Vagrant.}
  s.homepage      = VagrantPlugins::ProviderLibvirt::HOMEPAGE

  s.files         = Dir.glob("{lib,locales}/**/*") + %w(LICENSE README.md)
  s.executables   = Dir.glob("bin/*.*").map{ |f| File.basename(f) }
  s.test_files    = Dir.glob("{test,spec,features}/**/*.*")
  s.name          = 'vagrant-libvirt'
  s.require_paths = ['lib']
  s.version       = VagrantPlugins::ProviderLibvirt.get_version

  s.add_development_dependency "contextual_proc"
  s.add_development_dependency "rspec-core", "~> 3.5.0"
  s.add_development_dependency "rspec-expectations", "~> 3.5.0"
  s.add_development_dependency "rspec-mocks", "~> 3.5.0"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "simplecov-lcov"

  s.add_runtime_dependency 'fog-libvirt', '>= 0.6.0'
  s.add_runtime_dependency 'fog-core', '~> 2.1'

  # Make sure to allow use of the same version as Vagrant by being less specific
  s.add_runtime_dependency 'nokogiri', '~> 1.6'

  s.add_development_dependency 'rake'
end
