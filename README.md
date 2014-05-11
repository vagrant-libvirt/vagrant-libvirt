# Vagrant Libvirt Provider

This is a [Vagrant](http://www.vagrantup.com) 1.4.3+ plugin that adds an
[Libvirt](http://libvirt.org) provider to Vagrant, allowing Vagrant to
control and provision machines via Libvirt toolkit.

**Note:** Actual version (0.0.15) is still a development one. Feedback is
welcome and can help a lot :-)

## Features

* Control local Libvirt hypervisors.
* Vagrant `up`, `destroy`, `suspend`, `resume`, `halt`, `ssh`, `reload` and `provision` commands.
* Upload box image (qcow2 format) to Libvirt storage pool.
* Create volume as COW diff image for domains.
* Create private networks.
* Create and boot Libvirt domains.
* SSH into domains.
* Setup hostname and network interfaces.
* Provision domains with any built-in Vagrant provisioner.
* Synced folder support via `rsync`, `nfs` or `9p`.
* Snapshots via [sahara](https://github.com/jedi4ever/sahara).
* Package caching via [vagrant-cachier](http://fgrehm.viewdocs.io/vagrant-cachier/).
* Use boxes from other Vagrant providers via [vagrant-mutate](https://github.com/sciurus/vagrant-mutate).

## Future work

* More boxes should be available.
* Take a look at [open issues](https://github.com/pradels/vagrant-libvirt/issues?state=open).

## Installation

Install using standard [Vagrant 1.4.3+](http://downloads.vagrantup.com) plugin installation methods. After
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
    libvirt.driver = "kvm"
    libvirt.host = "localhost"
    libvirt.connect_via_ssh = true
    libvirt.username = "root"
    libvirt.storage_pool_name = "default"

    # include as many of these addition disks as you want to
    libvirt.storage :file,
      #:path => '',		# automatically chosen if unspecified!
      #:device => 'vdb',	# automatically chosen if unspecified!
      #:size => '10G',		# defaults to 10G if unspecified!
      :type => 'qcow2'		# defaults to 'qcow2' if unspecified!
  end
end
```

### Libvirt Configuration Options

This provider exposes quite a few provider-specific configuration options:

* `driver` - A hypervisor name to access. For now only kvm and qemu are supported.
* `host` - The name of the server, where libvirtd is running.
* `connect_via_ssh` - If use ssh tunnel to connect to Libvirt.
* `username` - Username and password to access Libvirt.
* `password` - Password to access Libvirt.
* `id_ssh_key_file` - The id ssh key file name to access Libvirt (eg: id_dsa or id_rsa or ... in the user .ssh directory)
* `socket` - Path to the libvirt unix socket (eg: /var/run/libvirt/libvirt-sock)
* `storage_pool_name` - Libvirt storage pool name, where box image and instance snapshots will be stored.

### Domain Specific Options

* `disk_bus` - The type of disk device to emulate. Defaults to virtio if not set. Possible values are documented in libvirt's [description for _target_](http://libvirt.org/formatdomain.html#elementsDisks).
* `memory` - Amount of memory in MBytes. Defaults to 512 if not set.
* `cpus` - Number of virtual cpus. Defaults to 1 if not set.
* `nested` - [Enable nested virtualization](https://github.com/torvalds/linux/blob/master/Documentation/virtual/kvm/nested-vmx.txt). Default is false.
* `cpu_mode` - What cpu mode to use for nested virtualization. Defaults to 'host-model' if not set.
* `volume_cache` - Controls the cache mechanism. Possible values are "default", "none", "writethrough", "writeback", "directsync" and "unsafe". [See driver->cache in libvirt documentation](http://libvirt.org/formatdomain.html#elementsDisks).
* `kernel` - To launch the guest with a kernel residing on host filesystems. Equivalent to qemu `-kernel`.
* `initrd` - To specify the initramfs/initrd to use for the guest. Equivalent to qemu `-initrd`.
* `cmd_line` - Arguments passed on to the guest kernel initramfs or initrd to use. Equivalent to qemu `-append`.


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
7.	Sync folders and run Vagrant provisioner on new domain if
	setup in Vagrantfile.

## Networks

Networking features in the form of `config.vm.network` support private networks
concept.

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
* `:dev` - Physical device that the public interface should use. Default is 'eth0'.
* `:mode` - The mode in which the public interface should operate in. Supported
  modes are available from the [libvirt documentation](http://www.libvirt.org/formatdomain.html#elementsNICSDirect).
  Default mode is 'bridge'.
* `:mac` - MAC address for the interface.

### Management Network

Vagrant-libvirt uses a private network to perform some management operations
on VMs. All VMs will have an interface connected to this network and
an IP address dynamically assigned by libvirt. This is in addition to any
networks you configure. The name and address used by this network are
configurable at the provider level.

* `management_network_name` - Name of libvirt network to which all VMs will be connected. If not specified the default is 'vagrant-libvirt'.
* `management_network_address` - Address of network to which all VMs will be connected. Must include the address and subnet mask. If not specified the default is '192.168.121.0/24'.

You may wonder how vagrant-libvirt knows the IP address a VM received.
Libvirt doesn't provide a standard way to find out the IP address of a running
domain. But we do know the MAC address of the virtual machine's interface on
the management network. Libvirt is closely connected with dnsmasq, which acts as
a DHCP server. dnsmasq writes lease information in the `/var/lib/libvirt/dnsmasq`
directory. Vagrant-libvirt looks for the MAC address in this file and extracts
the corresponding IP address.

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

## Forwarded Ports

vagrant-libvirt supports Forwarded Ports via ssh port forwarding.  For each
`forwarded_port` directive you specify in your Vagrantfile, vagrant-libvirt
will maintain an active ssh process for the lifetime of the VM.

## Synced Folders

vagrant-libvirt supports bidirectional synced folders via nfs or 9p and
unidirectional via rsync. The default is nfs. Vagrant automatically syncs
the project folder on the host to */vagrant* in the guest. You can also
configure additional synced folders.

You can change the synced folder type for */vagrant* by explicity configuring
it an setting the type, e.g.

    config.vm.synced_folder './', '/vagrant', type: 'rsync'


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

IMPORTANT NOTE: bundle is crucial. You need to use bundled vagrant.

## Contributing

1. Fork it.
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Commit your changes (`git commit -am 'Add some feature'`).
4. Push to the branch (`git push origin my-new-feature`).
5. Create new Pull Request.

