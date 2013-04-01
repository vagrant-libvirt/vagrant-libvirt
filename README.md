# Vagrant Libvirt Provider

This is a [Vagrant](http://www.vagrantup.com) 1.1+ plugin that adds an
[Libvirt](http://libvirt.org) provider to Vagrant, allowing Vagrant to
control and provision machines via Libvirt toolkit.

This plugin is inspired by existing [vagrant-aws](https://github.com/mitchellh/vagrant-aws) provider.

**Note:** This plugin requires Vagrant 1.1+.

## Features

* Upload box image (qcow2 format) to Libvirt storage pool.
* Create volume as COW diff image for domains.
* Create and boot Libvirt domains.
* SSH into domains.
* Provision domains with any built-in Vagrant provisioner.
* Minimal synced folder support via `rsync`.

## Usage

Install using standard Vagrant 1.1+ plugin installation methods. After
installing, `vagrant up` and specify the `libvirt` provider. An example is
shown below.

```
$ vagrant plugin install vagrant-libvirt
...
$ vagrant up --provider=libvirt
...
```

Of course prior to doing this, you'll need to obtain an Libvirt-compatible
box file for Vagrant. 

### Problems with plugin installation

In case of problems with building nokogiri gem, install missing development
libraries libxslt and libxml2.

In Ubuntu, Debian, ...
```
$ sudo apt-get install libxslt-dev libxml2-dev
```

In RedHat, Centos, Fedora, ...
```
# yum install libxslt-devel libxml2-devel
```

## Quick Start

After installing the plugin (instructions above), the quickest way to get
started is to add Libvirt box and specify all the details manually within
a `config.vm.provider` block. So first, add Libvirt box using any name you
want. This is just an example of Libvirt CentOS 6.4 box available:

```
$ vagrant box add centos64 http://kwok.cz/centos64.box
...
```

And then make a Vagrantfile that looks like the following, filling in
your information where necessary.

```
Vagrant.configure("2") do |config|
  config.vm.define :test_vm do |test_vm|
    test_vm.vm.box = "centos64"
  end

  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "qemu"
    libvirt.host = "example.com"
    libvirt.connect_via_ssh = true
    libvirt.username = "root"
    #libvirt.password = "secret"
    libvirt.storage_pool_name = "default"
  end
end

```

And then run `vagrant up --provider=libvirt`. Other way to tell Vagrant to
use Libvirt provider is to setup environment variable `export VAGRANT_DEFAULT_PROVIDER=libvirt`.

This will first upload box image to remote Libvirt storage pool as new volume.
Then create and start a CentOS 6.4 domain on example.com Libvirt host. In this
example configuration, connection to Libvirt is tunneled via SSH.

## Box Format

Every provider in Vagrant must introduce a custom box format. This
provider introduces `Libvirt` boxes. You can view an example box in
the [example_box/directory](https://github.com/pradels/vagrant-libvirt/tree/master/example_box). That directory also contains instructions on how to build a box.

The box format is qcow2 image file `box.img`, the required `metadata.json` file
along with a `Vagrantfile` that does default settings for the
provider-specific configuration for this provider.

## Configuration

This provider exposes quite a few provider-specific configuration options:

* `driver` - A hypervisor name to access. For now only qemu is supported.
* `host` - The name of the server, where libvirtd is running.
* `connect_via_ssh` - If use ssh tunnel to connect to Libvirt.
* `username` - Username and password to access Libvirt.
* `password` - Password to access Libvirt.
* `storage_pool_name` - Libvirt storage pool name, where box image and
  instance snapshots will be stored.

## Networks

Networking features in the form of `config.vm.network` are supported only
in bridged format, no hostonly network is supported in current version of
provider.

Example of network interface definition:

```
  config.vm.define :test_vm do |test_vm|
    test_vm.vm.network :bridged, :bridge => "default", :adapter => 1
  end
```

Bridged network adapter connected to network `default` is defined.

## Getting IP address

There is a little problem to find out which IP address was assigned to remote
domain. Fog library uses SSH connection to remote libvirt host and by default
checks arpwatch entries there.

Vagrant Libvirt provider is using dnsmasq leases files to find out, which IPs
dhcp server offered. VMs IP address is then saved to `$data_dir/ip` file for
later use. Of course, VMs IP can be changed over time. That's why IP is
checked, if matches with VMs MAC address after each reading from this state
file. Mismatch error is shown if IP doesn't match.


## Synced Folders

There is minimal support for synced folders. Upon `vagrant up`, the Libvirt
provider will use `rsync` (if available) to uni-directionally sync the folder
to the remote machine over SSH.

This is good enough for all built-in Vagrant provisioners (shell,
chef, and puppet) to work!

## Development

To work on the `vagrant-libvirt` plugin, clone this repository out, and use
[Bundler](http://gembundler.com) to get the dependencies:

```
$ bundle
```

Once you have the dependencies, verify the unit tests pass with `rake`:

```
$ bundle exec rake
```

If those pass, you're ready to start developing the plugin. You can test
the plugin without installing it into your Vagrant environment by just
creating a `Vagrantfile` in the top level of this directory (it is gitignored)
that uses it, and uses bundler to execute Vagrant:

```
$ bundle exec vagrant up --provider=libvirt
```

## Future work

Take a look on [open issues](https://github.com/pradels/vagrant-libvirt/issues?state=open).
