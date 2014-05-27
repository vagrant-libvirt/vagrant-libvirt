#!/usr/bin/env rake

#require 'rubygems'
#require 'bundler/setup'
require 'bundler/gem_tasks'
Bundler::GemHelper.install_tasks
task default: [:deftask]
task :deftask do
  puts 'call rake -T'
end

task :remote_install => :build  do
  sh "cp pkg/vagrant-libvirt-0.0.15.gem testboxes/vagrant-libvirt-installtest/"
  sh "cd testboxes/vagrant-libvirt-installtest && " +
     "vagrant ssh -c 'vagrant plugin install /vagrant/vagrant-libvirt-0.0.15.gem'"
end
