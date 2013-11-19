# Vagrant Libvirt Provider

This is a [Vagrant](http://www.vagrantup.com) 1.3+ plugin that adds an
[Libvirt](http://libvirt.org) provider to Vagrant, allowing Vagrant to
control and provision machines via Libvirt toolkit.

**Note:** Actual version (0.0.11) is still a development one. Feedback is
welcome and can help a lot :-)

## Features (Version 0.0.11)

* Controll local Libvirt hypervisors.
* Vagrant `up`, `destroy`, `suspend`, `resume`, `halt`, `ssh`, `reload` and `provision` commands.
* Upload box image (qcow2 format) to Libvirt storage pool.
* Create volume as COW diff image for domains.
* Create private networks.
* Create and boot Libvirt domains.
* SSH into domains.
* Setup hostname and network interfaces.
* Provision domains with any built-in Vagrant provisioner.
* Synced folder support via `rsync` or `nfs`.
* Snapshots via [sahara](https://github.com/jedi4ever/sahara)

## Future work

* More boxes should be available.
* Take a look at [open issues](https://github.com/pradels/vagrant-libvirt/issues?state=open).

## Installation

Install using standard [Vagrant 1.3+](http://downloads.vagrantup.com) plugin installation methods. After
installing, `vagrant up` and specify the `libvirt` provider. An example is shown below.

```
$ vagrant plugin install vagrant-libvirt
```

### Possible problems with plugin installation on Linux

In case of problems with building nokogiri and ruby-libvirt gem, install
missing development libraries for libxslt, libxml2 and libvirt.

In Ubuntu, Debian, ...
```
$ sudo apt-get install libxslt-dev libxml2-dev libvirt-dev
```

In RedHat, Centos, Fedora, ...
```
# yum install libxslt-devel libxml2-devel libvirt-devel
```

## Vagrant Project Preparation

After installing the plugin (instructions above), the quickest way to get
started is to add Libvirt box and specify all the details manually within
a `config.vm.provider` block. So first, add Libvirt box using any name you
want. This is just an example of Libvirt CentOS 6.4 box available:

```
$ vagrant box add centos64 http://kwok.cz/centos64.box
```

And then make a Vagrantfile that looks like the following, filling in your
information where necessary. In example below, VM named test_vm is created from
centos64 box and setup with 10.20.30.40 IP address.

```ruby
Vagrant.configure("2") do |config|

  # If you are still using old centos box, you have to setup root username for
  # ssh access. Read more in section 'SSH Access To VM'.
  config.ssh.username = "root"

  config.vm.define :test_vm do |test_vm|
    test_vm.vm.box = "centos64"
    test_vm.vm.network :private_network, :ip => '10.20.30.40'
  end

  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "qemu"
    libvirt.host = "localhost"
    libvirt.connect_via_ssh = true
    libvirt.username = "root"
    libvirt.storage_pool_name = "default"
  end
end
```

### Libvirt Configuration Options

This provider exposes quite a few provider-specific configuration options:

* `driver` - A hypervisor name to access. For now only qemu is supported.
* `host` - The name of the server, where libvirtd is running.
* `connect_via_ssh` - If use ssh tunnel to connect to Libvirt.
* `username` - Username and password to access Libvirt.
* `password` - Password to access Libvirt.
* `id_ssh_key_file` - The id ssh key file name to access Libvirt (eg: id_dsa or id_rsa or ... in the user .ssh directory)
* `storage_pool_name` - Libvirt storage pool name, where box image and instance snapshots will be stored.
* `default_network` - Libvirt default network name. If not specified default network name is 'default'.

### Domain Specific Options

* `memory` - Amount of memory in MBytes. Defaults to 512 if not set.
* `cpus` - Number of virtual cpus. Defaults to 1 if not set.
* `nested` - [Enable nested virtualization](https://github.com/torvalds/linux/blob/master/Documentation/virtual/kvm/nested-vmx.txt). Default is false.
* `volume_cache` - Controls the cache mechanism. Possible values are "default", "none", "writethrough", "writeback", "directsync" and "unsafe". [See driver->cache in libvirt documentation](http://libvirt.org/formatdomain.html#elementsDisks).

Specific domain settings can be set for each domain separately in multi-VM
environment. Example below shows a part of Vagrantfile, where specific options
are set for dbserver domain.

```ruby
Vagrant.configure("2") do |config|
  config.vm.define :dbserver do |dbserver|
    dbserver.vm.box = "centos64"
    dbserver.vm.provider :libvirt do |domain|
      domain.memory = 2048
      domain.cpus = 2
      domain.nested = true
	  domain.volume_cache = 'none'
    end
  end

  # ...
```

## Create Project - Vagrant up

In prepared project directory, run following command:

```
$ vagrant up --provider=libvirt
```

Vagrant needs to know that we want to use Libvirt and not default VirtualBox.
That's why there is `--provider=libvirt` option specified. Other way to tell
Vagrant to use Libvirt provider is to setup environment variable
`export VAGRANT_DEFAULT_PROVIDER=libvirt`.

### How Project Is Created

Vagrant goes through steps below when creating new project:

1.	Connect to Libvirt localy or remotely via SSH.
2.	Check if box image is available in Libvirt storage pool. If not, upload it to
	remote Libvirt storage pool as new volume.
3.	Create COW diff image of base box image for new Libvirt domain.
4.	Create and start new domain on Libvirt host.
5.	Check for DHCP lease from dnsmasq server.
6.	Wait till SSH is available.
7.	Sync folders via `rsync` and run Vagrant provisioner on new domain if
	setup in Vagrantfile.

## Networks

Networking features in the form of `config.vm.network` support private networks
concept. Port Forwarding is currently not supported.

Public Network interfaces are currently implemented using the macvtap driver. The macvtap
driver is only available with the Linux Kernel version >= 2.6.24. See the following libvirt
documentation for the details of the macvtap usage.

http://www.libvirt.org/formatdomain.html#elementsNICSDirect

An examples of network interface definitions:

```ruby
  # Private network
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :private_network, :ip => "10.20.30.40"
  end

  # Public Network
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :public_network, :dev => "eth0", :mode => 'bridge'
  end
```

In example below, one network interface is configured for VM test_vm1. After
you run `vagrant up`, VM will be accessible on IP address 10.20.30.40. So if
you install a web server via provisioner, you will be able to access your
testing server on http://10.20.30.40 URL. But beware that this address is
private to libvirt host only. It's not visible outside of the hypervisor box.

If network 10.20.30.0/24 doesn't exist, provider will create it. By default
created networks are NATed to outside world, so your VM will be able to connect
to the internet (if hypervisor can). And by default, DHCP is offering addresses
on newly created networks.

The second interface is created and bridged into the physical device 'eth0'.
This mechanism uses the macvtap Kernel driver and therefore does not require
an existing bridge device. This configuration assumes that DHCP and DNS services
are being provided by the public network. This public interface should be reachable
by anyone with access to the public network.

### Private Network Options

*Note: These options are not applicable to public network interfaces.*

There is a way to pass specific options for libvirt provider when using
`config.vm.network` to configure new network interface. Each parameter name
starts with 'libvirt__' string. Here is a list of those options:

* `:libvirt__network_name` - Name of libvirt network to connect to. By default,
  network 'default' is used.
* `:libvirt__netmask` - Used only together with `:ip` option. Default is
  '255.255.255.0'.
* `:libvirt__dhcp_enabled` - If DHCP will offer addresses, or not. Used only
  when creating new network. Default is true.
* `:libvirt__adapter` - Number specifiyng sequence number of interface.
* `:libvirt__forward_mode` - Specify one of `none`, `nat` or `route` options.
  This option is used only when creating new network. Mode `none` will create
  isolated network without NATing or routing outside. You will want to use
  NATed forwarding typically to reach networks outside of hypervisor. Routed
  forwarding is typically useful to reach other networks within hypervisor.
  By default, option `nat` is used.
* `:libvirt__forward_device` - Name of interface/device, where network should
  be forwarded (NATed or routed). Used only when creating new network. By
  default, all physical interfaces are used.
* `:mac` - MAC address for the interface.

### Public Network Options
* `:dev` - Physical device that the public interface should use. Default is 'eth0'
* `:mode` - The mode in which the public interface should operate in. Supported
  modes are available from the [libvirt documentation](http://www.libvirt.org/formatdomain.html#elementsNICSDirect).
  Default mode is 'bridge'.
* `:mac` - MAC address for the interface.

## Obtaining Domain IP Address

Libvirt doesn't provide standard way how to find out an IP address of running
domain. But we know, what is MAC address of virtual machine. Libvirt is closely
connected with dnsmasq server, which acts also as a DHCP server. Dnsmasq server
makes lease information public in `/var/lib/libvirt/dnsmasq` directory, or in
`/var/lib/misc/dnsmasq.leases` file on some systems. This is the place, where
information like which MAC address has which IP address resides and it's parsed
by vagrant-libvirt plugin.

## SSH Access To VM

There are some configuration options for ssh access to VM via `config.ssh.*` in
Vagrantfile. Untill provider version 0.0.5, root user was hardcoded and used to
access VMs ssh. Now, vagrant user is used by default, but it's configurable via
`config.ssh.username` option in Vagrantfile now.

If you are still using CentOS 6.4 box from example in this README, please set
ssh username back to root, because user vagrant is not usable (I forgot to add
necessary ssh key to his authorized_keys).

Configurable ssh parameters in Vagrantfile after provider version 0.0.5 are:

* `config.ssh.username` - Default is username vagrant.
* `config.ssh.guest_port` - Default port is set to 22.
* `config.ssh.forward_agent` - Default is false.
* `config.ssh.forward_x11` - Default is false.

## Synced Folders

There is minimal support for synced folders. Upon `vagrant up`, the Libvirt
provider will use `rsync` (if available) to uni-directionally sync the folder
to the remote machine over SSH.

This is good enough for all built-in Vagrant provisioners (shell,
chef, and puppet) to work!

If used options `:nfs => true`, folder will exported by nfs.

## Box Format

You can view an example box in the [example_box/directory](https://github.com/pradels/vagrant-libvirt/tree/master/example_box). That directory also contains instructions on how to build a box.

The box is a tarball containing:

* qcow2 image file named `box.img`.
* `metadata.json` file describing box image (provider, virtual_size, format).
* `Vagrantfile` that does default settings for the provider-specific configuration for this provider.

## Development

To work on the `vagrant-libvirt` plugin, clone this repository out, and use
[Bundler](http://gembundler.com) to get the dependencies:

```
$ git clone https://github.com/pradels/vagrant-libvirt.git
$ cd vagrant-libvirt
$ bundle install
```

Once you have the dependencies, verify the unit tests pass with `rake`:

```
$ bundle exec rake
```

If those pass, you're ready to start developing the plugin. You can test
the plugin without installing it into your Vagrant environment by just
creating a `Vagrantfile` in the top level of this directory (it is gitignored)
that uses it. Don't forget to add following line at the beginning of your
`Vagrantfile` while in development mode:

```ruby
Vagrant.require_plugin "vagrant-libvirt"
```

Now you can use bundler to execute Vagrant:

```
$ bundle exec vagrant up --provider=libvirt
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

