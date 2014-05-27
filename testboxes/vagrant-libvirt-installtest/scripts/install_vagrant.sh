#!/bin/bash
sudo apt-get -y update
sudo apt-get -y upgrade
wget https://dl.bintray.com/mitchellh/vagrant/vagrant_1.6.2_x86_64.deb
sudo dpkg -i /home/vagrant/vagrant_1.6.2_x86_64.deb
sudo apt-get -y install build-essential
sudo apt-get -y install libvirt-dev
vagrant plugin install vagrant-mutate
