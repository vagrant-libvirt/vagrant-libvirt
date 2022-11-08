# frozen_string_literal: true
#require 'rubygems'
#require 'bundler/setup'
require "parallel_tests"
require 'bundler/gem_tasks'
require File.expand_path('../lib/vagrant-libvirt/version', __FILE__)

Bundler::GemHelper.install_tasks
task default: [:deftask]
task :deftask do
  puts 'call rake -T'
end

task :write_version do
  VagrantPlugins::ProviderLibvirt.write_version()
end

task :clean_version do
  rm_rf File.expand_path('../lib/vagrant-libvirt/version', __FILE__)
end

task "clean" => :clean_version
task :write_version => :clean_version
task "build" => :write_version
task "release" => :write_version
