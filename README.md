# Vagrant Libvirt Provider
[![Build Status](https://travis-ci.org/vagrant-libvirt/vagrant-libvirt.svg)](https://travis-ci.org/vagrant-libvirt/vagrant-libvirt)

This is a [Vagrant](http://www.vagrantup.com) plugin that adds an
[Libvirt](http://libvirt.org) provider to Vagrant, allowing Vagrant to
control and provision machines via Libvirt toolkit.

**Note:** Actual version is still a development one. Feedback is welcome and
can help a lot :-)

- [Features](#features)
- [Future work](#future-work)
- [Installation](#installation)
  - [Possible problems with plugin installation on Linux](#possible-problems-with-plugin-installation-on-linux)
- [Vagrant Project Preparation](#vagrant-project-preparation)
  - [Add Box](#add-box)
  - [Create Vagrantfile](#create-vagrantfile)
  - [Start VM](#start-vm)
  - [How Project Is Created](#how-project-is-created)
  - [Libvirt Configuration](#libvirt-configuration)
  - [Provider Options](#provider-options)
  - [Domain Specific Options](#domain-specific-options)
    - [Reload behavior](#reload-behavior)
- [Networks](#networks)
  - [Private Network Options](#private-network-options)
  - [Public Network Options](#public-network-options)
  - [Management Network](#management-network)
- [Additional Disks](#additional-disks)
    - [Reload behavior](#reload-behavior-1)
- [CDROMs](#cdroms)
- [Input](#input)
- [PCI device passthrough](#pci-device-passthrough)
- [USB Redirector Devices](#usb-redirector-devices)
- [Random number generator passthrough](#random-number-generator-passthrough)
- [CPU Features](#cpu-features)
- [No box and PXE boot](#no-box-and-pxe-boot)
- [SSH Access To VM](#ssh-access-to-vm)
- [Forwarded Ports](#forwarded-ports)
- [Synced Folders](#synced-folders)
- [Customized Graphics](#customized-graphics)
- [Box Format](#box-format)
- [Create Box](#create-box)
- [Development](#development)
- [Contributing](#contributing)

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
* Synced folder support via `rsync`, `nfs` or `9p`.
* Snapshots via [sahara](https://github.com/jedi4ever/sahara).
* Package caching via
  [vagrant-cachier](http://fgrehm.viewdocs.io/vagrant-cachier/).
* Use boxes from other Vagrant providers via
  [vagrant-mutate](https://github.com/sciurus/vagrant-mutate).
* Support VMs with no box for PXE boot purposes (Vagrant 1.6 and up)

## Future work

* Take a look at [open
  issues](https://github.com/vagrant-libvirt/vagrant-libvirt/issues?state=open).

## Installation

First, you should have both qemu and libvirt installed if you plan to run VMs
on your local system. For instructions, refer to your linux distribution's
documentation.

**NOTE:** Before you start using Vagrant-libvirt, please make sure your libvirt
and qemu installation is working correctly and you are able to create qemu or
kvm type virtual machines with `virsh` or `virt-manager`.

Next, you must have [Vagrant
installed](http://docs.vagrantup.com/v2/installation/index.html).
Vagrant-libvirt supports Vagrant 1.5, 1.6, 1.7 and 1.8. 
*We only test with the upstream version!* If you decide to install your distros
version and you run into problems, as a first step you should switch to upstream.

Now you need to make sure your have all the build dependencies installed for 
vagrant-libvirt. This depends on your distro. An overview:

* Ubuntu 12.04/14.04/16.04, Debian: 
```shell
apt-get build-dep vagrant ruby-libvirt
apt-get install qemu libvirt-bin ebtables dnsmasq
apt-get install libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev
```

(It is possible some users will already have libraries from the third line installed, but this is the way to make it work OOTB.)

* CentOS 6, 7, Fedora 21:
```shell
yum install qemu libvirt libvirt-devel ruby-devel gcc qemu-kvm
```

* Fedora 22 and up:
```shell
dnf -y install qemu libvirt libvirt-devel ruby-devel gcc
```

* Arch linux: look at tips and solutions from Arch wiki.
```shell
pacman -Sy vagrant
```

Now you're ready to install vagrant-libvirt using standard [Vagrant
plugin](http://docs.vagrantup.com/v2/plugins/usage.html) installation methods.

```shell
$ vagrant plugin install vagrant-libvirt
```

### Possible problems with plugin installation on Linux

In case of problems with building nokogiri and ruby-libvirt gem, install
missing development libraries for libxslt, libxml2 and libvirt.


On Ubuntu, Debian, make sure you are running all three of the `apt` commands above with `sudo`.


On RedHat, Centos, Fedora, ...

```shell
$ sudo dnf install libxslt-devel libxml2-devel libvirt-devel \
  libguestfs-tools-c ruby-devel gcc
```

On Arch linux it is recommended to follow [steps from ArchWiki](https://wiki.archlinux.org/index.php/Vagrant#vagrant-libvirt).

If have problem with installation - check your linker. It should be `ld.gold`:

```shell
sudo alternatives --set ld /usr/bin/ld.gold
# OR
sudo ln -fs /usr/bin/ld.gold /usr/bin/ld
```

If you have issues building ruby-libvirt, try the following:
```shell
CONFIGURE_ARGS='with-ldflags=-L/opt/vagrant/embedded/lib with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib' GEM_HOME=~/.vagrant.d/gems GEM_PATH=$GEM_HOME:/opt/vagrant/embedded/gems PATH=/opt/vagrant/embedded/bin:$PATH vagrant plugin install vagrant-libvirt
```

## Vagrant Project Preparation

### Add Box

After installing the plugin (instructions above), the quickest way to get
started is to add Libvirt box and specify all the details manually within a
`config.vm.provider` block. So first, add Libvirt box using any name you want.
You can find more libvirt ready boxes at
[Atlas](https://atlas.hashicorp.com/boxes/search?provider=libvirt). For
example:

```shell
vagrant init fedora/24-cloud-base
```

### Create Vagrantfile

And then make a Vagrantfile that looks like the following, filling in your
information where necessary. For example:

```ruby
Vagrant.configure("2") do |config|
  config.vm.define :test_vm do |test_vm|
    test_vm.vm.box = "fedora/24-cloud-base"
  end
end
```

### Start VM

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

### How Project Is Created

Vagrant goes through steps below when creating new project:

1. Connect to Libvirt localy or remotely via SSH.
2. Check if box image is available in Libvirt storage pool. If not, upload it
   to remote Libvirt storage pool as new volume.
3. Create COW diff image of base box image for new Libvirt domain.
4. Create and start new domain on Libvirt host.
5. Check for DHCP lease from dnsmasq server.
6. Wait till SSH is available.
7. Sync folders and run Vagrant provisioner on new domain if setup in
   Vagrantfile.

### Libvirt Configuration

### Provider Options

Although it should work without any configuration for most people, this
provider exposes quite a few provider-specific configuration options. The
following options allow you to configure how vagrant-libvirt connects to
libvirt, and are used to generate the [libvirt connection
URI](http://libvirt.org/uri.html):

* `driver` - A hypervisor name to access. For now only kvm and qemu are
  supported
* `host` - The name of the server, where libvirtd is running
* `connect_via_ssh` - If use ssh tunnel to connect to Libvirt. Absolutely
  needed to access libvirt on remote host. It will not be able to get the IP
  address of a started VM otherwise.
* `username` - Username and password to access Libvirt
* `password` - Password to access Libvirt
* `id_ssh_key_file` - If not nil, uses this ssh private key to access Libvirt.
  Default is `$HOME/.ssh/id_rsa`. Prepends `$HOME/.ssh/` if no directory
* `socket` - Path to the libvirt unix socket (e.g.
  `/var/run/libvirt/libvirt-sock`)
* `uri` - For advanced usage. Directly specifies what libvirt connection URI
  vagrant-libvirt should use. Overrides all other connection configuration
  options

Connection-independent options:

* `storage_pool_name` - Libvirt storage pool name, where box image and instance
  snapshots will be stored.

For example:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.host = "example.com"
  end
end
```

### Domain Specific Options

* `disk_bus` - The type of disk device to emulate. Defaults to virtio if not
  set. Possible values are documented in libvirt's [description for
  _target_](http://libvirt.org/formatdomain.html#elementsDisks). NOTE: this
  option applies only to disks associated with a box image. To set the bus type
  on additional disks, see the [Additional Disks](#additional-disks) section.
* `nic_model_type` - parameter specifies the model of the network adapter when
  you create a domain value by default virtio KVM believe possible values, see
  the [documentation for
  libvirt](https://libvirt.org/formatdomain.html#elementsNICSModel).
* `memory` - Amount of memory in MBytes. Defaults to 512 if not set.
* `cpus` - Number of virtual cpus. Defaults to 1 if not set.
* `nested` - [Enable nested
  virtualization](https://github.com/torvalds/linux/blob/master/Documentation/virtual/kvm/nested-vmx.txt).
  Default is false.
* `cpu_mode` - [CPU emulation
  mode](https://libvirt.org/formatdomain.html#elementsCPU). Defaults to
  'host-model' if not set. Allowed values: host-model, host-passthrough,
  custom.
* `cpu_model` - CPU Model. Defaults to 'qemu64' if not set and `cpu_mode` is
  `custom` and to '' otherwise. This can really only be used when setting
  `cpu_mode` to `custom`.
* `cpu_fallback` - Whether to allow libvirt to fall back to a CPU model close
  to the specified model if features in the guest CPU are not supported on the
  host. Defaults to 'allow' if not set. Allowed values: `allow`, `forbid`.
* `numa_nodes` - Number of NUMA nodes on guest. Must be a factor of `cpu`.
* `loader` - Sets path to custom UEFI loader.
* `volume_cache` - Controls the cache mechanism. Possible values are "default",
  "none", "writethrough", "writeback", "directsync" and "unsafe". [See
  driver->cache in libvirt
  documentation](http://libvirt.org/formatdomain.html#elementsDisks).
* `kernel` - To launch the guest with a kernel residing on host filesystems.
  Equivalent to qemu `-kernel`.
* `initrd` - To specify the initramfs/initrd to use for the guest. Equivalent
  to qemu `-initrd`.
* `random_hostname` - To create a domain name with extra information on the end
  to prevent hostname conflicts.
* `cmd_line` - Arguments passed on to the guest kernel initramfs or initrd to
  use. Equivalent to qemu `-append`.
* `graphics_type` - Sets the protocol used to expose the guest display.
  Defaults to `vnc`.  Possible values are "sdl", "curses", "none", "gtk", "vnc"
  or "spice".
* `graphics_port` - Sets the port for the display protocol to bind to.
  Defaults to 5900.
* `graphics_ip` - Sets the IP for the display protocol to bind to.  Defaults to
  "127.0.0.1".
* `graphics_passwd` - Sets the password for the display protocol. Working for
  vnc and spice. by default working without passsword.
* `graphics_autoport` - Sets autoport for graphics, libvirt in this case
  ignores graphics_port value, Defaults to 'yes'. Possible value are "yes" and
  "no"
* `keymap` - Set keymap for vm. default: en-us
* `kvm_hidden` - [Hide the hypervisor from the
  guest](https://libvirt.org/formatdomain.html#elementsFeatures). Useful for
  [GPU passthrough](#pci-device-passthrough) on stubborn drivers. Default is false.
* `video_type` - Sets the graphics card type exposed to the guest.  Defaults to
  "cirrus".  [Possible
  values](http://libvirt.org/formatdomain.html#elementsVideo) are "vga",
  "cirrus", "vmvga", "xen", "vbox", or "qxl".
* `video_vram` - Used by some graphics card types to vary the amount of RAM
  dedicated to video.  Defaults to 9216.
* `machine_type` - Sets machine type. Equivalent to qemu `-machine`. Use
  `qemu-system-x86_64 -machine help` to get a list of supported machines.
* `machine_arch` - Sets machine architecture. This helps libvirt to determine
  the correct emulator type. Possible values depend on your version of qemu.
  For possible values, see which emulator executable `qemu-system-*` your
  system provides. Common examples are `aarch64`, `alpha`, `arm`, `cris`,
  `i386`, `lm32`, `m68k`, `microblaze`, `microblazeel`, `mips`, `mips64`,
  `mips64el`, `mipsel`, `moxie`, `or32`, `ppc`, `ppc64`, `ppcemb`, `s390x`,
  `sh4`, `sh4eb`, `sparc`, `sparc64`, `tricore`, `unicore32`, `x86_64`,
  `xtensa`, `xtensaeb`.
* `machine_virtual_size` - Sets the disk size in GB for the machine overriding
  the default specified in the box. Allows boxes to defined with a minimal size
  disk by default and to be grown to a larger size at creation time. Will
  ignore sizes smaller than the size specified by the box metadata. Note that
  currently there is no support for automatically resizing the filesystem to
  take advantage of the larger disk.
* `emulator_path` - Explicitly select which device model emulator to use by
  providing the path, e.g. `/usr/bin/qemu-system-x86_64`. This is especially
  useful on systems that fail to select it automatically based on
  `machine_arch` which then results in a capability error.
* `boot` - Change the boot order and enables the boot menu. Possible options
  are "hd", "network", "cdrom". Defaults to "hd" with boot menu disabled. When
  "network" is set without "hd", only all NICs will be tried; see below for
  more detail.
* `nic_adapter_count` - Defaults to '8'. Only use case for increasing this
  count is for VMs that virtualize switches such as Cumulus Linux. Max value
  for Cumulus Linux VMs is 33.
* `uuid` - Force a domain UUID. Defaults to autogenerated value by libvirt if
  not set.
* `suspend_mode` - What is done on vagrant suspend. Possible values: 'pause',
  'managedsave'. Pause mode executes a la `virsh suspend`, which just pauses
  execution of a VM, not freeing resources. Managed save mode does a la `virsh
  managedsave` which frees resources suspending a domain.
* `tpm_model` - The model of the TPM to which you wish to connect.
* `tpm_type` - The type of TPM device to which you are connecting.
* `tpm_path` - The path to the TPM device on the host system.
* `dtb` - The device tree blob file, mostly used for non-x86 platforms. In case
  the device tree isn't added in-line to the kernel, it can be manually
  specified here.
* `autostart` - Automatically start the domain when the host boots. Defaults to
  'false'.
* `channel` - [libvirt
  channels](https://libvirt.org/formatdomain.html#elementCharChannel).
  Configure a private communication channel between the host and guest, e.g.
  for use by the [qemu guest
  agent](http://wiki.libvirt.org/page/Qemu_guest_agent) and the Spice/QXL
  graphics type.

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

The following example shows part of a Vagrantfile that enables the VM to boot
from a network interface first and a hard disk second. This could be used to
run VMs that are meant to be a PXE booted machines. Be aware that if `hd` is
not specified as a boot option, it will never be tried.

```ruby
Vagrant.configure("2") do |config|
  config.vm.define :pxeclient do |pxeclient|
    pxeclient.vm.box = "centos64"
    pxeclient.vm.provider :libvirt do |domain|
      domain.boot 'network'
      domain.boot 'hd'
    end
  end

  # ...
```

#### Reload behavior

On `vagrant reload` the following domain specific attributes are updated in
defined domain:

* `disk_bus` - Is updated only on disks. It skips CDROMs
* `nic_model_type` - Updated
* `memory` - Updated
* `cpus` - Updated
* `nested` - Updated
* `cpu_mode` - Updated. Pay attention that custom mode is not supported
* `graphics_type` - Updated
* `graphics_port` - Updated
* `graphics_ip` - Updated
* `graphics_passwd` - Updated
* `graphics_autoport` - Updated
* `keymap` - Updated
* `video_type` - Updated
* `video_vram` - Updated
* `tpm_model` - Updated
* `tpm_type` - Updated
* `tpm_path` - Updated

## Networks

Networking features in the form of `config.vm.network` support private networks
concept. It supports both the virtual network switch routing types and the
point to point Guest OS to Guest OS setting using UDP/Mcast/TCP tunnel
interfaces.

http://wiki.libvirt.org/page/VirtualNetworking

https://libvirt.org/formatdomain.html#elementsNICSTCP

http://libvirt.org/formatdomain.html#elementsNICSMulticast

http://libvirt.org/formatdomain.html#elementsNICSUDP _(in libvirt v1.2.20 and higher)_

Public Network interfaces are currently implemented using the macvtap driver.
The macvtap driver is only available with the Linux Kernel version >= 2.6.24.
See the following libvirt documentation for the details of the macvtap usage.

http://www.libvirt.org/formatdomain.html#elementsNICSDirect

An examples of network interface definitions:

```ruby
  # Private network using virtual network switching
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :private_network, :ip => "10.20.30.40"
  end

  # Private network. Point to Point between 2 Guest OS using a TCP tunnel
  # Guest 1
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :private_network,
      :libvirt__tunnel_type => 'server',
      # default is 127.0.0.1 if omitted
      # :libvirt__tunnel_ip => '127.0.0.1',
      :libvirt__tunnel_port => '11111'

  # Guest 2
  config.vm.define :test_vm2 do |test_vm2|
    test_vm2.vm.network :private_network,
      :libvirt__tunnel_type => 'client',
      # default is 127.0.0.1 if omitted
      # :libvirt__tunnel_ip => '127.0.0.1',
      :libvirt__tunnel_port => '11111'


  # Public Network
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :public_network,
      :dev => "virbr0",
      :mode => "bridge",
      :type => "bridge"
  end
```

In example below, one network interface is configured for VM `test_vm1`. After
you run `vagrant up`, VM will be accessible on IP address `10.20.30.40`. So if
you install a web server via provisioner, you will be able to access your
testing server on `http://10.20.30.40` URL. But beware that this address is
private to libvirt host only. It's not visible outside of the hypervisor box.

If network `10.20.30.0/24` doesn't exist, provider will create it. By default
created networks are NATed to outside world, so your VM will be able to connect
to the internet (if hypervisor can). And by default, DHCP is offering addresses
on newly created networks.

The second interface is created and bridged into the physical device `eth0`.
This mechanism uses the macvtap Kernel driver and therefore does not require an
existing bridge device. This configuration assumes that DHCP and DNS services
are being provided by the public network. This public interface should be
reachable by anyone with access to the public network.

### Private Network Options

*Note: These options are not applicable to public network interfaces.*

There is a way to pass specific options for libvirt provider when using
`config.vm.network` to configure new network interface. Each parameter name
starts with `libvirt__` string. Here is a list of those options:

* `:libvirt__network_name` - Name of libvirt network to connect to. By default,
  network 'default' is used.
* `:libvirt__netmask` - Used only together with `:ip` option. Default is
  '255.255.255.0'.
* `:libvirt__host_ip` - Adress to use for the host (not guest).  Default is
  first possible address (after network address).
* `:libvirt__dhcp_enabled` - If DHCP will offer addresses, or not. Used only
  when creating new network. Default is true.
* `:libvirt__dhcp_start` - First address given out via DHCP.  Default is third
  address in range (after network name and gateway).
* `:libvirt__dhcp_stop` - Last address given out via DHCP.  Default is last
  possible address in range (before broadcast address).
* `:libvirt__dhcp_bootp_file` - The file to be used for the boot image.  Used
  only when dhcp is enabled.
* `:libvirt__dhcp_bootp_server` - The server that runs the DHCP server.  Used
  only when dhcp is enabled.By default is the same host that runs the DHCP
  server.
* `:libvirt__adapter` - Number specifiyng sequence number of interface.
* `:libvirt__forward_mode` - Specify one of `veryisolated`, `none`, `nat` or
  `route` options.  This option is used only when creating new network. Mode
  `none` will create isolated network without NATing or routing outside. You
  will want to use NATed forwarding typically to reach networks outside of
  hypervisor. Routed forwarding is typically useful to reach other networks
  within hypervisor.  `veryisolated` described
  [here](https://libvirt.org/formatnetwork.html#examplesNoGateway).  By
  default, option `nat` is used.
* `:libvirt__forward_device` - Name of interface/device, where network should
  be forwarded (NATed or routed). Used only when creating new network. By
  default, all physical interfaces are used.
* `:libvirt__tunnel_type` - Set to 'udp' if using UDP unicast tunnel mode
  (libvirt v1.2.20 or higher).  Set this to either "server" or "client" for tcp
  tunneling. Set this to 'mcast' if using multicast tunneling. This
  configuration type uses tunnels to generate point to point connections
  between Guests. Useful for Switch VMs like Cumulus Linux. No virtual switch
  setting like `libvirt__network_name` applies with tunnel interfaces and will
  be ignored if configured.
* `:libvirt__tunnel_ip` - Sets the source IP of the libvirt tunnel interface.
  By default this is `127.0.0.1` for TCP and UDP tunnels and `239.255.1.1` for
  Multicast tunnels. It populates the address field in the `<source
  address="XXX">` of the interface xml configuration.
* `:libvirt__tunnel_port` - Sets the source port the tcp/udp/mcast tunnel with
  use. This port information is placed in the `<source port=XXX/>` section of
  interface xml configuration.
* `:libvirt__tunnel_local_port` - Sets the local port used by the udp tunnel
  interface type. It populates the port field in the `<local port=XXX">`
  section of the interface xml configuration. _(This feature only works in
  libvirt 1.2.20 and higher)_
* `:libvirt__tunnel_local_ip` - Sets the local IP used by the udp tunnel
  interface type. It populates the ip entry of the `<local address=XXX">`
  section of the interface xml configuration. _(This feature only works in
  libvirt 1.2.20 and higher)_
* `:libvirt__guest_ipv6` - Enable or disable guest-to-guest IPv6 communication.
  See [here](https://libvirt.org/formatnetwork.html#examplesPrivate6), and
  [here](http://libvirt.org/git/?p=libvirt.git;a=commitdiff;h=705e67d40b09a905cd6a4b8b418d5cb94eaa95a8)
  for for more information. *Note: takes either 'yes' or 'no' for value*
* `:libvirt__iface_name` - Define a name for the private network interface.
  With this feature one can [simulate physical link
  failures](https://github.com/vagrant-libvirt/vagrant-libvirt/pull/498)
* `:mac` - MAC address for the interface. *Note: specify this in lowercase
  since Vagrant network scripts assume it will be!*
* `:model_type` - parameter specifies the model of the network adapter when you
  create a domain value by default virtio KVM believe possible values, see the
  documentation for libvirt

When the option `:libvirt__dhcp_enabled` is to to 'false' it shouldn't matter
whether the virtual network contains a DHCP server or not and vagrant-libvirt
should not fail on it. The only situation where vagrant-libvirt should fail is
when DHCP is requested but isn't configured on a matching already existing
virtual network.

### Public Network Options

* `:dev` - Physical device that the public interface should use. Default is
  'eth0'.
* `:mode` - The mode in which the public interface should operate in. Supported
  modes are available from the [libvirt
  documentation](http://www.libvirt.org/formatdomain.html#elementsNICSDirect).
  Default mode is 'bridge'.
* `:type` - is type of interface.(`<interface type="#{@type}">`)
* `:mac` - MAC address for the interface.
* `:network_name` - Name of libvirt network to connect to.
* `:portgroup` - Name of libvirt portgroup to connect to.
* `:ovs` - Support to connect to an Open vSwitch bridge device. Default is
  'false'.
* `:trust_guest_rx_filters` - Support trustGuestRxFilters attribute. Details
  are listed [here](http://www.libvirt.org/formatdomain.html#elementsNICSDirect).
  Default is 'false'.

### Management Network

vagrant-libvirt uses a private network to perform some management operations on
VMs. All VMs will have an interface connected to this network and an IP address
dynamically assigned by libvirt. This is in addition to any networks you
configure. The name and address used by this network are configurable at the
provider level.

* `management_network_name` - Name of libvirt network to which all VMs will be
  connected. If not specified the default is 'vagrant-libvirt'.
* `management_network_address` - Address of network to which all VMs will be
  connected. Must include the address and subnet mask. If not specified the
  default is '192.168.121.0/24'.
* `management_network_mode` - Network mode for the libvirt management network.
  Specify one of veryisolated, none, nat or route options. Further documentated
  under [Private Networks](#private-network-options)
* `management_network_guest_ipv6` - Enable or disable guest-to-guest IPv6
  communication. See
  [here](https://libvirt.org/formatnetwork.html#examplesPrivate6), and
  [here](http://libvirt.org/git/?p=libvirt.git;a=commitdiff;h=705e67d40b09a905cd6a4b8b418d5cb94eaa95a8)
  for for more information.

You may wonder how vagrant-libvirt knows the IP address a VM received.  Libvirt
doesn't provide a standard way to find out the IP address of a running domain.
But we do know the MAC address of the virtual machine's interface on the
management network. Libvirt is closely connected with dnsmasq, which acts as a
DHCP server. dnsmasq writes lease information in the `/var/lib/libvirt/dnsmasq`
directory. Vagrant-libvirt looks for the MAC address in this file and extracts
the corresponding IP address.

## Additional Disks

You can create and attach additional disks to a VM via `libvirt.storage :file`.
It has a number of options:

* `path` - Location of the disk image. If unspecified, a path is automtically
  chosen in the same storage pool as the VMs primary disk.
* `device` - Name of the device node the disk image will have in the VM, e.g.
  *vdb*. If unspecified, the next available device is chosen.
* `size` - Size of the disk image. If unspecified, defaults to 10G.
* `type` - Type of disk image to create. Defaults to *qcow2*.
* `bus` - Type of bus to connect device to. Defaults to *virtio*.
* `cache` - Cache mode to use, e.g. `none`, `writeback`, `writethrough` (see
  the [libvirt documentation for possible
  values](http://libvirt.org/formatdomain.html#elementsDisks) or
  [here](https://www.suse.com/documentation/sles11/book_kvm/data/sect1_chapter_book_kvm.html)
  for a fuller explanation). Defaults to *default*.
* `allow_existing` - Set to true if you want to allow the VM to use a
  pre-existing disk. If the disk doesn't exist it will be created.
  Disks with this option set to true need to be removed manually.
* `shareable` - Set to true if you want to simulate shared SAN storage.

The following example creates two additional disks.

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.storage :file, :size => '20G'
    libvirt.storage :file, :size => '40G', :type => 'raw'
  end
end
```

For shared SAN storage to work the following example can be used:
```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.storage :file, :size => '20G', :path => 'my_shared_disk.img', :allow_existing => true, :shareable => true, :type => 'raw'
  end
end
```

### Reload behavior

On `vagrant reload` the following additional disk attributes are updated in
defined domain:

* `bus` - Updated. Uses `device` as a search marker. It is not required to
  define `device`, but it's recommended. If `device` is defined then the order
  of addtitional disk definition becomes irrelevant.

## CDROMs

You can attach up to four CDROMs to a VM via `libvirt.storage :file,
:device => :cdrom`. Available options are:

* `path` - The path to the iso to be used for the CDROM drive.
* `dev` - The device to use (`hda`, `hdb`, `hdc`, or `hdd`). This will be
  automatically determined if unspecified.
* `bus` - The bus to use for the CDROM drive. Defaults to `ide`

The following example creates three CDROM drives in the VM:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.storage :file, :device => :cdrom, :path => '/path/to/iso1.iso'
    libvirt.storage :file, :device => :cdrom, :path => '/path/to/iso2.iso'
    libvirt.storage :file, :device => :cdrom, :path => '/path/to/iso3.iso'
  end
end
```

## Input

You can specify multiple inputs to the VM via `libvirt.input`. Available
options are listed below. Note that both options are required:

* `type` - The type of the input
* `bus` - The bus of the input

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # this is the default
    # libvirt.input :type => "mouse", :bus => "ps2"

    # very useful when having mouse issues when viewing VM via VNC
    libvirt.input :type => "tablet", :bus => "usb"
  end
end
```

## PCI device passthrough

You can specify multiple PCI devices to passthrough to the VM via
`libvirt.pci`. Available options are listed below. Note that all options are
required:

* `bus` - The bus of the PCI device
* `slot` - The slot of the PCI device
* `function` - The function of the PCI device

You can extract that information from output of `lspci` command. First
characters of each line are in format `[<bus>]:[<slot>].[<func>]`. For example:

```shell
$ lspci| grep NVIDIA
03:00.0 VGA compatible controller: NVIDIA Corporation GK110B [GeForce GTX TITAN Black] (rev a1)
```

In that case `bus` is `0x03`, `slot` is `0x00` and `function` is `0x0`.

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.pci :bus => '0x06', :slot => '0x12', :function => '0x5'

    # Add another one if it is neccessary
    libvirt.pci :bus => '0x03', :slot => '0x00', :function => '0x0'
  end
end
```

Note! Above options affect configuration only at domain creation. It won't change VM behaviour on `vagrant reload` after domain was created.

Don't forget to [set](#domain-specific-options) `kvm_hidden` option to `true` especially if you are passthroughing NVIDIA GPUs. Otherwise GPU is visible from VM but cannot be operated.

## USB Redirector Devices
You can specify multiple redirect devices via `libvirt.redirdev`. There are two types, `tcp` and `spicevmc` supported, for forwarding USB-devices to the guest. Available options are listed below.

* `type` - The type of the USB redirector device. (`tcp` or `spicevmc`)
* `host` - The host where the device is attached to. (mandatory for type `tcp`)
* `port` - The port where the device is listening. (mandatory for type `tcp`)

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # add two devices using spicevmc channel
    (1..2).each do
      libvirt.redirdev :type => "spicevmc"
    end
    # add device, provided by localhost:4000
    libvirt.redirdev :type => "tcp", :host => "localhost", :port => "4000"
  end
end
```

### Filter for USB Redirector Devices
You can define filter for redirected devices. These filters can be positiv or negative, by setting the mandatory option `allow=yes` or `allow=no`. All available options are listed below. Note the option `allow` is mandatory.

* `class` - The device class of the USB device. A list of device classes is available on [Wikipedia](https://en.wikipedia.org/wiki/USB#Device_classes).
* `vendor` - The vendor of the USB device.
* `product` - The product id of the USB device.
* `version` - The version of the USB device. Note that this is the version of `bcdDevice`
* `allow` - allow or disallow redirecting this device. (mandatory)

You can extract that information from output of `lsusb` command. Every line contains the information in format `Bus [<bus>] Device [<device>]: ID [<vendor>:[<product>]`. The `version` can be extracted from the detailed output of the device using `lsusb -D /dev/usb/[<bus>]/[<device>]`. For example:

```shell
# get bcdDevice from 
$: lsusb
Bus 001 Device 009: ID 08e6:3437 Gemalto (was Gemplus) GemPC Twin SmartCard Reader

$: lsusb -D /dev/bus/usb/001/009 | grep bcdDevice
  bcdDevice            2.00
```

In this case, the USB device with `class 0x0b`, `vendor 0x08e6`, `product 0x3437` and `bcdDevice version 2.00` is allowed to be redirected to the guest. All other devices will be refused.

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.redirdev :type => "spicevmc"
    libvirt.redirfilter :class => "0x0b" :vendor => "0x08e6" :product => "0x3437" :version => "2.00" :allow => "yes"
    libvirt.redirfilter :allow => "no"
  end
end
```

## Random number generator passthrough

You can pass through `/dev/random` to your VM by configuring the domain like this:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Pass through /dev/random from the host to the VM
    libvirt.random :model => 'random'
  end
end
```

At the moment only the `random` backend is supported.

## CPU features

You can specify CPU feature policies via `libvirt.cpu_feature`. Available
options are listed below. Note that both options are required:

* `name` - The name of the feature for the chosen CPU (see libvirts
  `cpu_map.xml`)
* `policy` - The policy for this feature (one of `force`, `require`,
  `optional`, `disable` and `forbid` - see libvirt documentation)

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # The feature will not be supported by virtual CPU.
    libvirt.cpu_feature :name => 'hypervisor', :policy => 'disable'
    # Guest creation will fail unless the feature is supported by host CPU.
    libvirt.cpu_feature :name => 'vmx', :policy => 'require'
    # The virtual CPU will claim the feature is supported regardless of it being supported by host CPU.
    libvirt.cpu_feature :name => 'pdpe1gb', :policy => 'force'
  end
end
```

## USB device passthrough

You can specify multiple USB devices to passthrough to the VM via
`libvirt.usb`. The device can be specified by the following options:

* `bus` - The USB bus ID, e.g. "1"
* `device` - The USB device ID, e.g. "2"
* `vendor` - The USB devices vendor ID (VID), e.g. "0x1234"
* `product` - The USB devices product ID (PID), e.g. "0xabcd"

At least one of these has to be specified, and `bus` and `device` may only be
used together.

The example values above match the device from the following output of `lsusb`:

```
Bus 001 Device 002: ID 1234:abcd Example device
```

Additionally, the following options can be used:

* `startupPolicy` - Is passed through to libvirt and controls if the device has
  to exist.  libvirt currently allows the following values: "mandatory",
  "requisite", "optional".

## No box and PXE boot

There is support for PXE booting VMs with no disks as well as PXE booting VMs
with blank disks. There are some limitations:

* Requires Vagrant 1.6.0 or newer
* No provisioning scripts are ran
* No network configuration is being applied to the VM
* No SSH connection can be made
* `vagrant halt` will only work cleanly if the VM handles ACPI shutdown signals

In short, VMs without a box can be created, halted and destroyed but all other
functionality cannot be used.

An example for a PXE booted VM with no disks whatsoever:

```ruby
Vagrant.configure("2") do |config|
  config.vm.define :pxeclient do |pxeclient|
    pxeclient.vm.provider :libvirt do |domain|
      domain.boot 'network'
    end
  end
end
```

And an example for a PXE booted VM with no box but a blank disk which will boot from this HD if the NICs fail to PXE boot:

```ruby
Vagrant.configure("2") do |config|
  config.vm.define :pxeclient do |pxeclient|
    pxeclient.vm.provider :libvirt do |domain|
      domain.storage :file, :size => '100G', :type => 'qcow2'
      domain.boot 'network'
      domain.boot 'hd'
    end
  end
end
```

## SSH Access To VM

vagrant-libvirt supports vagrant's [standard ssh
settings](https://docs.vagrantup.com/v2/vagrantfile/ssh_settings.html).

## Forwarded Ports

vagrant-libvirt supports Forwarded Ports via ssh port forwarding. Please note
that due to a well known limitation only the TCP protocol is supported. For
each `forwarded_port` directive you specify in your Vagrantfile,
vagrant-libvirt will maintain an active ssh process for the lifetime of the VM.

vagrant-libvirt supports an additional `forwarded_port` option `gateway_ports`
which defaults to `false`, but can be set to `true` if you want the forwarded
port to be accessible from outside the Vagrant host.  In this case you should
also set the `host_ip` option to `'*'` since it defaults to `'localhost'`.

You can also provide a custom adapter to forward from by 'adapter' option.
Default is `eth0`.

## Synced Folders

vagrant-libvirt supports bidirectional synced folders via nfs or 9p and
unidirectional via rsync. The default is nfs. Vagrant automatically syncs the
project folder on the host to `/vagrant` in the guest. You can also configure
additional synced folders.

You can change the synced folder type for `/vagrant` by explicity configuring
it an setting the type, e.g.

```shell
config.vm.synced_folder './', '/vagrant', type: 'rsync'
```

or

```shell
config.vm.synced_folder './', '/vagrant', type: '9p', disabled: false, accessmode: "squash", owner: "1000"
```

or

```shell
config.vm.synced_folder './', '/vagrant', type: '9p', disabled: false, accessmode: "mapped", mount: false
```

For 9p shares, a `mount: false` option allows to define synced folders without
mounting them at boot.

Further documentation on using 9p can be found [here](https://www.kernel.org/doc/Documentation/filesystems/9p.txt). Please do note that 9p depends on support in the guest and not all distros come with the 9p module by default.

**SECURITY NOTE:** for remote libvirt, nfs synced folders requires a bridged
public network interface and you must connect to libvirt via ssh.


## Customized Graphics

vagrant-libvirt supports customizing the display and video settings of the
managed guest.  This is probably most useful for VNC-type displays with
multiple guests.  It lets you specify the exact port for each guest to use
deterministically.

Here is an example of using custom display options:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.graphics_port = 5901
    libvirt.graphics_ip = '0.0.0.0'
    libvirt.video_type = 'qxl'
  end
end
```

## TPM Devices

Modern versions of Libvirt support connecting to TPM devices on the host
system. This allows you to enable Trusted Boot Extensions, among other
features, on your guest VMs.

In general, you will only need to modify the `tpm_path` variable in your guest
configuration. However, advanced usage, such as the application of a Software
TPM, may require modifying the `tpm_model` and `tpm_type` variables.

The TPM options will only be used if you specify a TPM path. Declarations of
any TPM options without specifying a path will result in those options being
ignored.

Here is an example of using the TPM options:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.tpm_model = 'tpm-tis'
    libvirt.tpm_type = 'passthrough'
    libvirt.tpm_path = '/dev/tpm0'
  end
end
```

## Libvirt communication channels

For certain functionality to be available within a guest, a private
communication channel must be established with the host. Two notable examples
of this are the qemu guest agent, and the Spice/QXL graphics type.

Below is a simple example which exposes a virtio serial channel to the guest.
Note: in a multi-VM environment, the channel would be created for all VMs.

```ruby
vagrant.configure(2) do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
  end
end
```

Below is the syntax for creating a spicevmc channel for use by a qxl graphics
card.

```ruby
vagrant.configure(2) do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.channel :type => 'spicevmc', :target_name => 'com.redhat.spice.0', :target_type => 'virtio'
  end
end
```

These settings can be specified on a per-VM basis, however the per-guest
settings will OVERRIDE any global 'config' setting. In the following example,
we create 3 VM with the following configuration:

* **master**: No channel settings specified, so we default to the provider
  setting of a single virtio guest agent channel.
* **node1**: Override the channel setting, setting both the guest agent
  channel, and a spicevmc channel
* **node2**: Override the channel setting, setting both the guest agent
  channel, and a 'guestfwd' channel. TCP traffic sent by the guest to the given
  IP address and port is forwarded to the host socket `/tmp/foo`. Note: this
  device must be unique for each VM.

For example:

```ruby
Vagrant.configure(2) do |config|
  config.vm.box = "fedora/24-cloud-base"
  config.vm.provider :libvirt do |libvirt|
    libvirt.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
  end

  config.vm.define "master" do |master|
    master.vm.provider :libvirt do |domain|
        domain.memory = 1024
    end
  end
  config.vm.define "node1" do |node1|
    node1.vm.provider :libvirt do |domain|
      domain.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
      domain.channel :type => 'spicevmc', :target_name => 'com.redhat.spice.0', :target_type => 'virtio'
    end
  end
  config.vm.define "node2" do |node2|
    node2.vm.provider :libvirt do |domain|
      domain.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
      domain.channel :type => 'unix', :target_type => 'guestfwd', :target_address => '192.0.2.42', :target_port => '4242',
                     :source_path => '/tmp/foo'
    end
  end
end
```

## Box Format

You can view an example box in the
[`example_box/directory`](https://github.com/vagrant-libvirt/vagrant-libvirt/tree/master/example_box).
That directory also contains instructions on how to build a box.

The box is a tarball containing:

* qcow2 image file named `box.img`
* `metadata.json` file describing box image (`provider`, `virtual_size`,
  `format`)
* `Vagrantfile` that does default settings for the provider-specific
  configuration for this provider

## Create Box

To create a vagrant-libvirt box from a qcow2 image, run `create_box.sh`
(located in the tools directory):

```shell
$ create_box.sh ubuntu14.qcow2
```

You can also create a box by using [Packer](https://packer.io). Packer
templates for use with vagrant-libvirt are available at
https://github.com/jakobadam/packer-qemu-templates. After cloning that project
you can build a vagrant-libvirt box by running:

```shell
$ cd packer-qemu-templates
$ packer build ubuntu-14.04-server-amd64-vagrant.json
```

## Development

To work on the `vagrant-libvirt` plugin, clone this repository out, and use
[Bundler](http://gembundler.com) to get the dependencies:

```shell
$ git clone https://github.com/vagrant-libvirt/vagrant-libvirt.git
$ cd vagrant-libvirt
$ bundle install
```

Once you have the dependencies, verify the unit tests pass with `rspec`:

```shell
$ bundle exec rspec spec/
```

If those pass, you're ready to start developing the plugin. You can test the
plugin without installing it into your Vagrant environment by just creating a
`Vagrantfile` in the top level of this directory (it is gitignored) that uses
it. Don't forget to add following line at the beginning of your `Vagrantfile`
while in development mode:

```ruby
Vagrant.require_plugin "vagrant-libvirt"
```

Now you can use bundler to execute Vagrant:

```shell
$ bundle exec vagrant up --provider=libvirt
```

**IMPORTANT NOTE:** bundle is crucial. You need to use bundled Vagrant.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
