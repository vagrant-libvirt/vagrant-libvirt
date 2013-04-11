# -*- encoding: utf-8 -*-
require File.expand_path('../lib/vagrant-libvirt/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Lukas Stanek"]
  gem.email         = ["ls@elostech.cz"]
  gem.description   = %q{Vagrant provider for libvirt.}
  gem.summary       = %q{Vagrant provider for libvirt.}
  gem.homepage      = "https://github.com/pradels/vagrant-libvirt"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "vagrant-libvirt"
  gem.require_paths = ["lib"]
  gem.version       = VagrantPlugins::Libvirt::VERSION

  gem.add_runtime_dependency "fog", "~> 1.10.0"
  gem.add_runtime_dependency "ruby-libvirt", "~> 0.4.0"

  gem.add_development_dependency "rake"
end

