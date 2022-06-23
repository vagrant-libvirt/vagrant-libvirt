---
title: Boxes
nav_order: 4
toc: true
---

## Existing Boxes

Libvirt ready boxes can be downloaded at
[Vagrant Cloud](https://app.vagrantup.com/boxes/search?provider=libvirt).



## Creating Boxes

It's possible to also create custom boxes using existing boxes as the initial
starting point.

<div class="info">
If creating a box from a modified vagrant-libvirt machine, ensure that you have set the
<code class="language-plaintext highlighter-rouge">config.ssh.insert_key = false</code>
in the original Vagrantfile as otherwise Vagrant will replace the default connection
key-pair that is required on first boot with one specific to the machine and prevent
the default key from working on the exported result.
{% highlight ruby %}
Vagrant.configure("2") do |config|
  # this setting is only recommended if planning to export the
  # resulting machine
  config.ssh.insert_key = false

  config.vm.define :test_vm do |test_vm|
    test_vm.vm.box = "fedora/32-cloud-base"
  end
end
{% endhighlight %}
</div>

### Using Vagrant Package

vagrant-libvirt has native support for [`vagrant
package`](https://www.vagrantup.com/docs/cli/package.html) via
libguestfs [virt-sysprep](http://libguestfs.org/virt-sysprep.1.html).
virt-sysprep operations can be customized via the
`VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS` environment variable; see the
[upstream
documentation](http://libguestfs.org/virt-sysprep.1.html#operations) for
further details especially on default sysprep operations enabled for
your system.

Options to the virt-sysprep command call can be passed via
`VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS` environment variable.

```shell
$ export VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS="--delete /etc/hostname"
$ vagrant package
```

For example, on Chef [bento](https://github.com/chef/bento) VMs that
require SSH hostkeys already set (e.g. bento/debian-7) as well as leave
existing LVM UUIDs untouched (e.g. bento/ubuntu-18.04), these can be
packaged into vagrant-libvirt boxes like so:

```shell
$ export VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS="defaults,-ssh-userdir,-ssh-hostkeys,-lvm-uuids"
$ vagrant package
```

### From qcow2 Image

To create a vagrant-libvirt box from a qcow2 image, run `create_box.sh`
(located in the tools directory):

```shell
$ create_box.sh ubuntu14.qcow2
```

### Packer

You can also create a box by using [Packer](https://packer.io). Packer
templates for use with vagrant-libvirt are available at
https://github.com/jakobadam/packer-qemu-templates. After cloning that project
you can build a vagrant-libvirt box by running:

```shell
$ cd packer-qemu-templates
$ packer build ubuntu-14.04-server-amd64-vagrant.json
```

## Box Formats

### Version 1

This is the original format that most boxes currently use.

You can view an example box in the
[`example_box/directory`](https://github.com/vagrant-libvirt/vagrant-libvirt/tree/master/example_box).
That directory also contains instructions on how to build a box.

The box is a tarball containing:

* qcow2 image file named `box.img`
* `metadata.json` file describing box image (`provider`, `virtual_size`,
  `format`)
* `Vagrantfile` that does default settings for the provider-specific
  configuration for this provider


### Version 2 (Experimental)

Due to the limitation of only being able to handle a single disk with the version 1 format, a new
format was added to support boxes that need to specify multiple disks. This is still currently
experimental and as such is not the default format. Packaging support is in place and will automatically
alert you if attempting to package a machine with additional disks attached. To enable the new format
to verify ahead of it becoming the default, export the variable `VAGRANT_LIBVIRT_BOX_FORMAT_VERSION=v2`
before running `vagrant package`

Additionally there is a script in the tools folder
([`tools/create_box_with_two_disks.sh`](https://github.com/vagrant-libvirt/vagrant-libvirt/blob/master/tools/create_box_with_two_disks.sh))
that provides a guideline on how to create such a box from qcow2 images should it not be practical use
a vagrant machine with additional storage as a starting point.

At it's most basic, it expects an array of disks to allow a specific order to be presented. Disks
will be attached in this order and as such assume device names base on this within the VM. The
'path' attribute is required, and is expected to be relative to the base of the box. This should
allow placing the disk images within a nested directory within the box if it useful for those
with a larger number of disks. The name allows overriding the target volume name that will be
used in the libvirt storage pool. Note that vagrant-libvirt will still prefix the volume name
with `#{box_name}_vagrant_box_image_#{box_version}_` to avoid accidental clashes with other boxes.

Format and virtual size need no longer be specified as they are now retrieved directly from the
provided image using `qemu-img info ...`.

Example format:
```json
{
  "disks": [
      {
          "path": "disk1.img"
      },
      {
          "path": "disk2.img",
          "name": "secondary_disk"
      },
      {
          "path": "disk3.img"
      }
  ],
  "provider": "libvirt"
}
```
