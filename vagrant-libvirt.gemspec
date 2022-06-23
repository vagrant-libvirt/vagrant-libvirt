# -*- encoding: utf-8 -*-
# frozen_string_literal: true
require File.expand_path('../lib/vagrant-libvirt/version', __FILE__)

Gem::Specification.new do |s|
  s.authors       = ['Lukas Stanek','Dima Vasilets','Brian Pitts','Darragh Bailey']
  s.email         = ['ls@elostech.cz','pronix.service@gmail.com','brian@polibyte.com','daragh.bailey@gmail.com']
  s.license       = 'MIT'
  s.description   = %q{libvirt provider for Vagrant.}
  s.summary       = %q{libvirt provider for Vagrant.}
  s.homepage      = VagrantPlugins::ProviderLibvirt::HOMEPAGE
  s.metadata      = {
    "source_code_uri" => VagrantPlugins::ProviderLibvirt::HOMEPAGE,
  }

  s.files         = Dir.glob("{lib,locales}/**/*") + %w(LICENSE README.md)
  s.executables   = Dir.glob("bin/*.*").map{ |f| File.basename(f) }
  s.test_files    = Dir.glob("{test,spec,features}/**/*.*")
  s.name          = 'vagrant-libvirt'
  s.require_paths = ['lib']
  s.version       = VagrantPlugins::ProviderLibvirt.get_version

  s.add_runtime_dependency 'fog-libvirt', '>= 0.6.0'
  s.add_runtime_dependency 'fog-core', '~> 2'
  s.add_runtime_dependency 'rexml'
  s.add_runtime_dependency 'diffy'

  # Make sure to allow use of the same version as Vagrant by being less specific
  s.add_runtime_dependency 'nokogiri', '~> 1.6'

  s.add_development_dependency 'rake'
  s.add_development_dependency "rspec-core", ">= 3.5"
  s.add_development_dependency "rspec-expectations", ">= 3.5"
  s.add_development_dependency "rspec-mocks", ">= 3.5"
end
