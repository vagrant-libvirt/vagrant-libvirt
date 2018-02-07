# -*- encoding: utf-8 -*-
# stub: vagrant-libvirt 0.0.41 ruby lib
require File.expand_path('../lib/vagrant-libvirt/version', __FILE__)

Gem::Specification.new do |s|
  s.name = "vagrant-libvirt".freeze
  s.version = VagrantPlugins::ProviderLibvirt::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Lukas Stanek".freeze, "Dima Vasilets".freeze, "Brian Pitts".freeze]
  s.files         = `git ls-files`.split($\)
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})

  s.description = "libvirt provider for Vagrant.".freeze
  s.email = ["ls@elostech.cz".freeze, "pronix.service@gmail.com".freeze, "brian@polibyte.com".freeze]
  s.homepage = "https://github.com/vagrant-libvirt/vagrant-libvirt".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.6.14".freeze
  s.summary = "libvirt provider for Vagrant.".freeze

  s.installed_by_version = "2.6.14" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec-core>.freeze, ["~> 3.5.0"])
      s.add_development_dependency(%q<rspec-expectations>.freeze, ["~> 3.5.0"])
      s.add_development_dependency(%q<rspec-mocks>.freeze, ["~> 3.5.0"])
      s.add_runtime_dependency(%q<fog-libvirt>.freeze, [">= 0.3.0"])
      s.add_runtime_dependency(%q<nokogiri>.freeze, [">= 1.6.0"])
      s.add_runtime_dependency(%q<fog-core>.freeze, ["~> 1.43.0"])
      s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    else
      s.add_dependency(%q<rspec-core>.freeze, ["~> 3.5.0"])
      s.add_dependency(%q<rspec-expectations>.freeze, ["~> 3.5.0"])
      s.add_dependency(%q<rspec-mocks>.freeze, ["~> 3.5.0"])
      s.add_dependency(%q<fog-libvirt>.freeze, [">= 0.3.0"])
      s.add_dependency(%q<nokogiri>.freeze, [">= 1.6.0"])
      s.add_dependency(%q<fog-core>.freeze, ["~> 1.43.0"])
      s.add_dependency(%q<rake>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<rspec-core>.freeze, ["~> 3.5.0"])
    s.add_dependency(%q<rspec-expectations>.freeze, ["~> 3.5.0"])
    s.add_dependency(%q<rspec-mocks>.freeze, ["~> 3.5.0"])
    s.add_dependency(%q<fog-libvirt>.freeze, [">= 0.3.0"])
    s.add_dependency(%q<nokogiri>.freeze, [">= 1.6.0"])
    s.add_dependency(%q<fog-core>.freeze, ["~> 1.43.0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
  end
end
