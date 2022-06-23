---
title: Quickstart
redirect_from:
  - /home/
  - /quickstart/
  - /extras/
nav_order: 1
toc: true
---
Vagrant-libvirt is a [Vagrant](http://www.vagrantup.com) plugin that adds a
[Libvirt](http://libvirt.org) provider to Vagrant, allowing Vagrant to
control and provision machines via Libvirt toolkit.

{: .info }
Actual version is still a development one. Feedback is welcome and
can help a lot :-)

## Prerequisites

Vagrant-libvirt requires the following:

* Vagrant
* Libvirt (and QEMU)
* GCC and Make (if not using vagrant from your distribution)

{: .warn }
Before you start using vagrant-libvirt, please make sure your Libvirt
and QEMU installation is working correctly and you are able to create QEMU or
KVM type virtual machines with `virsh` or `virt-manager`.

See [Requirements]({{ '/installation/#requirements' | relative_url }}) for guides and details.

## Installation

1. Install Vagrant, Libvirt and QEMU for your distribution
   * Ubuntu

   ```
   sudo apt-get update && \
       sudo apt install -y qemu libvirt-daemon-system libvirt-clients \
           ebtables dnsmasq-base libguestfs-tools
   sudo apt install -y --no-install-recommends vagrant ruby-fog-libvirt
   ```

   * Fedora

   ```
   vagrant_libvirt_deps=($(sudo dnf repoquery --depends vagrant-libvirt 2>/dev/null | cut -d' ' -f1))
   dependencies=$(sudo dnf repoquery --qf "%{name}" ${vagrant_libvirt_deps[@]/#/--whatprovides })
   sudo dnf install --assumeyes --setopt=install_weak_deps=False @virtualization ${dependencies}
   ```
2. Install the latest release of vagrant-libvirt
```
vagrant plugin install vagrant-libvirt
```

If you encounter any errors during this process, check that you have installed all the prerequisites in [Requirements]({{ '/installation/#requirements' | relative_url }}).
If you still have issues, see [Troubleshooting]({{ '/troubleshooting/#installation-problems' | relative_url }}).

{: .info }
Installation varies based on your operating system or use of upstream vagrant. See our [guides]({{ '/installation/#guides' | relative_url }}) for OS-specific instructions.

## Initial Project Creation

After installing the plugin (instructions above), the quickest way to get
started is to add Libvirt box and specify all the details manually within a
`config.vm.provider` block. So first, add Libvirt box using any name you want.
You can find more Libvirt-ready boxes at
[Vagrant Cloud](https://app.vagrantup.com/boxes/search?provider=libvirt). For
example:

```shell
vagrant init fedora/36-cloud-base
```

Or make a Vagrantfile that looks like the following, filling in your
information where necessary. For example:

```ruby
Vagrant.configure("2") do |config|
  config.vm.define :test_vm do |test_vm|
    test_vm.vm.box = "fedora/36-cloud-base"
  end
end
```

## Start VM

In prepared project directory, run following command:

```shell
$ vagrant up --provider=libvirt
```

Vagrant needs to know that we want to use Libvirt and not default VirtualBox.
That's why there is `--provider=libvirt` option specified. Other way to tell
Vagrant to use Libvirt provider is to setup environment variable

```shell
export VAGRANT_DEFAULT_PROVIDER=libvirt
```
