---
layout: page
title: About
permalink: /about/
---

Vagrant-libvirt is a [Vagrant](http://www.vagrantup.com) plugin that adds a
[Libvirt](http://libvirt.org) provider to Vagrant, allowing Vagrant to
control and provision machines via Libvirt toolkit.

{: .info }
Actual version is still a development one. Feedback is welcome and
can help a lot :-)

You can find the source code for Vagrant Libvirt plugin at GitHub:
[https://github.com/vagrant-libvirt/vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt)

You can find the source code for Vagrant Libvirt QA testing of install instructions at GitHub:
[https://github.com/vagrant-libvirt/vagrant-libvirt-qa](https://github.com/vagrant-libvirt/vagrant-libvirt-qa)

Creating issues can be done via GitHub:
[https://github.com/vagrant-libvirt/vagrant-libvirt/issues](https://github.com/vagrant-libvirt/vagrant-libvirt/issues)


To ask questions or discuss a problem ahead of logging an issue you can use:
* Gitter [https://gitter.im/vagrant-libvirt/vagrant-libvirt](https://gitter.im/vagrant-libvirt/vagrant-libvirt)
* Github Discussions [https://github.com/vagrant-libvirt/vagrant-libvirt/discussions](https://github.com/vagrant-libvirt/vagrant-libvirt/discussions)

## Features

* Control local Libvirt hypervisors.
* Vagrant `up`, `destroy`, `suspend`, `resume`, `halt`, `ssh`, `reload`,
  `package` and `provision` commands.
* Upload box image (qcow2 format) to Libvirt storage pool.
* Create volume as COW diff image for domains.
* Create private networks.
* Create and boot Libvirt domains.
* SSH into domains.
* Setup hostname and network interfaces.
* Provision domains with any built-in Vagrant provisioner.
* Synced folder support via `rsync`, `nfs`, `9p` or `virtiofs`.
* Snapshots
* Package caching via
  [vagrant-cachier](http://fgrehm.viewdocs.io/vagrant-cachier/).
* Use boxes from other Vagrant providers via
  [vagrant-mutate](https://github.com/sciurus/vagrant-mutate).
* Support VMs with no box for PXE boot purposes (Vagrant 1.6 and up)

## How a Machine Is Created

Vagrant goes through steps below when creating new project:

1. Connect to Libvirt locally or remotely via SSH.
2. Check if box image is available in Libvirt storage pool. If not, upload it
   to remote Libvirt storage pool as new volume.
3. Create COW diff image of base box image for new Libvirt domain.
4. Create and start new domain on Libvirt host.
5. Check for DHCP lease from dnsmasq server.
6. Wait till SSH is available.
7. Sync folders and run Vagrant provisioner on new domain if setup in
   Vagrantfile.
