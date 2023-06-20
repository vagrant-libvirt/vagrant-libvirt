---
title: Configuration
nav_order: 3
toc: true
---


Although it should work without any configuration for most people, this
provider exposes quite a few provider-specific configuration options.

## Provider Options

### Connection Options

The following options allow you to configure how vagrant-libvirt connects to
Libvirt, and are used to generate the [Libvirt connection URI](http://libvirt.org/uri.html):

* `driver` - A hypervisor name to access. For now only KVM and QEMU are
  supported
* `host` - The name of the server, where Libvirtd is running
* `connect_via_ssh` - If use ssh tunnel to connect to Libvirt. Absolutely
  needed to access Libvirt on remote host. It will not be able to get the IP
  address of a started VM otherwise.
* `username` - Username and password to access Libvirt
* `password` - Password to access Libvirt
* `id_ssh_key_file` - If not nil, uses this ssh private key to access Libvirt.
  Default is `$HOME/.ssh/id_rsa`. Prepends `$HOME/.ssh/` if no directory
* `socket` - Path to the Libvirt unix socket (e.g.
  `/var/run/libvirt/libvirt-sock`)
* `uri` - For advanced usage. Directly specifies what Libvirt connection URI
  vagrant-libvirt should use. Overrides all above connection configuration
  options
* `proxy_command` - For advanced usage. When connecting to remote libvirt
  instances, if the default constructed proxy\_command which uses `-W %h:%p`
  does not work, set this as needed. It performs interpolation using `{key}`
  and supports only `{host}`, `{username}`, and `{id_ssh_key_file}`. This is
  to try and avoid issues with escaping `%` and `$` which might be necessary
  to the ssh command itself. e.g.:
  `libvirt.proxy_command = "ssh {host} -l {username} -i {id_ssh_key_file} nc %h %p"`

In the event that none of these are set (excluding the `driver` option) the
provider will attempt to retrieve the uri from the environment variable
`LIBVIRT_DEFAULT_URI` similar to how virsh works. If any of them are set, it
will ignore the environment variable. The reason the driver option is ignored
is that it is not uncommon for this to be explicitly set on the box itself
and there is no easily to determine whether it is being set by the user or
the box packager.

Connection-independent options:

* `storage_pool_name` - Libvirt storage pool name, where box image and instance
  snapshots (if `snapshot_pool_name` is not set) will be stored.
* `snapshot_pool_name` - Libvirt storage pool name. If set, the created
  snapshot of the instance will be stored at this location instead of
  `storage_pool_name`.

Connection example:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.host = "example.com"
  end
end
```

### Domain Specific Options

* `title` - A short description of the domain.
* `description` - A human readable description of the virtual machine.
* `random_hostname` - To create a domain name with extra information on the end
  to prevent hostname conflicts.
* `default_prefix` - The default Libvirt guest name becomes a concatenation of the
   `<current_directory>_<guest_name>`. The current working directory is the default prefix
   to the guest name. The `default_prefix` options allow you to set the guest name prefix.
* `disk_bus` - The type of disk device to emulate. Defaults to virtio if not
  set. Possible values are documented in Libvirt's [description for
  _target_](http://libvirt.org/formatdomain.html#hard-drives-floppy-disks-cdroms). NOTE: this
  option applies only to disks associated with a box image. To set the bus type
  on additional disks, see the [Additional Disks](#additional-disks) section.
* `disk_controller_model` - the controller model to use. Ignored unless either
  `disk_bus` is set to `scsi` or `disk_device` starts with `sd`, which is a hint
  to use scsi. Defaults to `virtio-scsi` when it encounters either of the
  config values for `disk_bus` or `disk_device`. See [libvirt controller models](
  https://libvirt.org/formatdomain.html#controllers) for other possible values.
  NOTE: this option applies only to the disks associated with a box image.
* `disk_device` - The disk device to emulate. Defaults to vda if not
  set, which should be fine for paravirtualized guests, but some fully
  virtualized guests may require hda. NOTE: this option also applies only to
  disks associated with a box image.
* `disk_address_type` - The address type of disk device to emulate.
  Libvirt uses a sensible default if not set, but some fully virtualized guests
  may need to override this (e.g. Debian on _virt_ machine may need _virtio-mmio_).
  Possible values are documented in libvirt's [description for
  _address_](https://libvirt.org/formatdomain.html#device-addresses).
* `disk_driver` - Extra options for the main disk driver ([see Libvirt documentation](http://libvirt.org/formatdomain.html#hard-drives-floppy-disks-cdroms)).
  NOTE: this option also applies only to disks associated with a box image. In all cases, the value `nil` can be used to force the hypervisor default behaviour (e.g. to override settings defined in top-level Vagrantfiles). Supported options include:
  * `:cache` - Controls the cache mechanism. Possible values are "default", "none", "writethrough", "writeback", "directsync" and "unsafe".
  * `:io` - Controls specific policies on I/O. Possible values are "threads" and "native".
  * `:copy_on_read` - Controls whether to copy read backing file into the image file. The value can be either "on" or "off".
  * `:discard` - Controls whether discard requests (also known as "trim" or "unmap") are ignored or passed to the filesystem. Possible values are "unmap" or "ignore".
    Note: for discard to work, you will likely also need to set `disk_bus = 'scsi'`
  * `:detect_zeroes` - Controls whether to detect zero write requests. The value can be "off", "on" or "unmap".
  * `address_type` - Address type of disk device to emulate. If unspecified, Libvirt uses a sensible default.
* `nic_model_type` - parameter specifies the model of the network adapter when you create a domain, default is 'virtio'. For possible values, see the [documentation for Libvirt](https://libvirt.org/formatdomain.html#setting-the-nic-model).
* `shares` - Proportional weighted share for the domain relative to others. For more details see [documentation](https://libvirt.org/formatdomain.html#cpu-tuning).
* `memory` - Amount of memory in MBytes. Defaults to 512 if not set.
* `cpus` - Number of virtual cpus. Defaults to 1 if not set.
* `cpuset` - Physical cpus to which the vcpus can be pinned. For more details see [documentation](https://libvirt.org/formatdomain.html#cpu-allocation).
* `cputopology` - Number of CPU sockets, cores and threads running per core. All fields of `:sockets`, `:cores` and `:threads` are mandatory, `cpus` domain option must be present and must be equal to total count of **sockets * cores * threads**. For more details see [documentation](https://libvirt.org/formatdomain.html#cpu-model-and-topology).

  ```ruby
  Vagrant.configure("2") do |config|
    config.vm.provider :libvirt do |libvirt|
      libvirt.cpus = 4
      libvirt.cpuset = '1-4,^3,6'
      libvirt.cputopology :sockets => '2', :cores => '2', :threads => '1'
    end
  end
  ```

* `cpuaffinitiy` - Mapping of vCPUs to host CPUs. [See `vcpupin`](https://libvirt.org/formatdomain.html#cpu-tuning).

  ```ruby
  Vagrant.configure("2") do |config|
    config.vm.provider :libvirt do |libvirt|
      libvirt.cpus = 4
      libvirt.cpuaffinitiy 0 => '0-4,^3', 1 => '5', 2 => '6,7'
    end
  end
  ```

* `nodeset` - Physical NUMA nodes where virtual memory can be pinned. For more details see [documentation](https://libvirt.org/formatdomain.html#numa-node-tuning).
* `nested` - [Enable nested virtualization](https://docs.fedoraproject.org/en-US/quick-docs/using-nested-virtualization-in-kvm/).
  Default is false.
* `cpu_mode` - [CPU emulation mode](https://libvirt.org/formatdomain.html#cpu-model-and-topology). Defaults to
  'host-model' if not set. Allowed values: host-model, host-passthrough,
  custom.
* `cpu_model` - CPU Model. Defaults to 'qemu64' if not set and `cpu_mode` is
  `custom` and to '' otherwise. This can really only be used when setting
  `cpu_mode` to `custom`.
* `cpu_fallback` - Whether to allow Libvirt to fall back to a CPU model close
  to the specified model if features in the guest CPU are not supported on the
  host. Defaults to 'allow' if not set. Allowed values: `allow`, `forbid`.
* `numa_nodes` - Specify an array of NUMA nodes for the guest. The syntax is similar to what would be set in the domain XML. `memory` must be in MB. Symmetrical and asymmetrical topologies are supported but make sure your total count of defined CPUs adds up to `v.cpus`.

  The sum of all the memory defined here will act as your total memory for your guest VM. **This sum will override what is set in `v.memory`**
  ```
  v.cpus = 4
  v.numa_nodes = [
    {:cpus => "0-1", :memory => "1024"},
    {:cpus => "2-3", :memory => "4096"}
  ]
  ```
* `launchsecurity` - Configure Secure Encryption Virtualization for the guest, requires additional components to be configured to work, see [examples](./examples.html#secure-encryption-virtualization). For more information look at [libvirt documentation](https://libvirt.org/kbase/launch_security_sev.html).
  ```
  libvirt.launchsecurity :type => 'sev', :cbitpos => 47, :reducedPhysBits => 1, :policy => "0x0003"
  ```
* `memtune` - Configure the memtune settings for the guest, primarily exposed to facilitate enabling Secure Encryption Virtualization. Note that when configuring `hard_limit` that the value is in kB as opposed to `libvirt.memory` which is in Mb. Additionally it must be set to be higher than `libvirt.memory`, see [libvirt documentation](https://libvirt.org/kbase/launch_security_sev.html) for details on why.
  ```
  libvirt.memtune :type => "hard_limit", :value => 2500000 # Note here the value in kB (not in Mb)
  ```
* `loader` - Sets path to custom UEFI loader.
* `kernel` - To launch the guest with a kernel residing on host filesystems.
  Equivalent to qemu `-kernel`.
* `initrd` - To specify the initramfs/initrd to use for the guest. Equivalent
  to qemu `-initrd`.
* `cmd_line` - Arguments passed on to the guest kernel initramfs or initrd to
  use. Equivalent to qemu `-append`, only possible to use in combination with `initrd` and `kernel`.
* `graphics_type` - Sets the protocol used to expose the guest display.
  Defaults to `vnc`.  Possible values are "sdl", "curses", "none", "gtk", "vnc"
  or "spice".
* `graphics_port` - Sets the port for the display protocol to bind to.
  Defaults to `-1`, which will be set automatically by libvirt.
* `graphics_websocket` - Sets the websocket port for the display protocol to bind to.
  Defaults to `-1`, which will be set automatically by libvirt.
  The autoport configuration has no effect on the websocket port due to security reasons.
* `graphics_ip` - Sets the IP for the display protocol to bind to.  Defaults to
  "127.0.0.1".
* `graphics_passwd` - Sets the password for the display protocol. Working for
  vnc and Spice. by default working without passsword.
* `graphics_autoport` - Sets autoport for graphics, Libvirt in this case
  ignores graphics_port value, Defaults to 'yes'. Possible value are "yes" and
  "no"
* `graphics_gl` - Set to `true` to enable OpenGL. Defaults to `true` if
`video_accel3d` is `true`.
* `keymap` - Set keymap for vm. default: en-us
* `kvm_hidden` - [Hide the hypervisor from the
  guest](https://libvirt.org/formatdomain.html#hypervisor-features). Useful for
  [GPU passthrough](#pci-device-passthrough) on stubborn drivers. Default is false.
* `video_type` - Sets the graphics card type exposed to the guest.  Defaults to
  "cirrus".  [Possible
  values](http://libvirt.org/formatdomain.html#video-devices) are "vga",
  "cirrus", "vmvga", "xen", "vbox", or "qxl".
* `video_vram` - Used by some graphics card types to vary the amount of RAM
  dedicated to video.  Defaults to 16384.
* `video_accel3d` - Set to `true` to enable 3D acceleration. Defaults to
`false`.
* `sound_type` - [Set the virtual sound card](https://libvirt.org/formatdomain.html#sound-devices)
  Defaults to "ich6".
* `machine_type` - Sets machine type. Equivalent to qemu `-machine`. Use
  `qemu-system-x86_64 -machine help` to get a list of supported machines.
* `machine_arch` - Sets machine architecture. This helps Libvirt to determine
  the correct emulator type. Possible values depend on your version of QEMU.
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
  more detail. Defining this in subsequent provider blocks or latter Vagrantfile's
  (see [Load Order and Merging](https://www.vagrantup.com/docs/vagrantfile)) will
  result in the definition in the last block being used.
* `nic_adapter_count` - Defaults to '8'. Only use case for increasing this
  count is for VMs that virtualize switches such as Cumulus Linux. Max value
  for Cumulus Linux VMs is 33.
* `uuid` - Force a domain UUID. Defaults to autogenerated value by Libvirt if
  not set.
* `suspend_mode` - What is done on vagrant suspend. Possible values: 'pause',
  'managedsave'. Pause mode executes a la `virsh suspend`, which just pauses
  execution of a VM, not freeing resources. Managed save mode does a la `virsh
  managedsave` which frees resources suspending a domain.
* `tpm_model` - The model of the TPM to which you wish to connect.
* `tpm_type` - The type of TPM device to which you are connecting.
* `tpm_path` - The path to the TPM device on the host system.
* `tpm_version` - The TPM version to use.
* `sysinfo` - The [SMBIOS System Information](https://libvirt.org/formatdomain.html#smbios-system-information) to use.
  This is a hash with key names aligning with the different section XML tags of
  bios, system, base board, chassis, and oem strings. Nested hashes then use
  entry attribute names as the keys for the values to assign, except for oem strings
  which is a simple array of strings.
* `dtb` - The device tree blob file, mostly used for non-x86 platforms. In case
  the device tree isn't added in-line to the kernel, it can be manually
  specified here.
* `autostart` - Automatically start the domain when the host boots. Defaults to
  'false'.
* `channel` - [Libvirt
  channels](https://libvirt.org/formatdomain.html#channel).
  Configure a private communication channel between the host and guest, e.g.
  for use by the [QEMU guest
  agent](http://wiki.libvirt.org/page/Qemu_guest_agent) and the Spice/QXL
  graphics type.
* `mgmt_attach` - Decide if VM has interface in mgmt network. If set to 'false'
  it is not possible to communicate with VM through `vagrant ssh` or run
  provisioning. Setting to 'false' is only possible when VM doesn't use box
  or vagrant is told not to connect via ssh. Defaults set to 'true'.
* `serial` - [libvirt serial devices](https://libvirt.org/formatdomain.html#consoles-serial-parallel-channel-devices).
  Configure a serial/console port to communicate with the guest. Can be used
  to log to file boot time messages sent to ttyS0 console by the guest.

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
      domain.disk_driver :cache => 'none'
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

### Reload behavior

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
* `graphics_websocket` - Updated
* `graphics_ip` - Updated
* `graphics_passwd` - Updated
* `graphics_autoport` - Updated
* `keymap` - Updated
* `video_type` - Updated
* `video_vram` - Updated
* `tpm_model` - Updated
* `tpm_type` - Updated
* `tpm_path` - Updated
* `tpm_version` - Updated

## Networks

Networking features in the form of `config.vm.network` support private networks
concept. It supports both the virtual network switch routing types and the
point to point Guest OS to Guest OS setting using UDP/Mcast/TCP tunnel
interfaces.

http://wiki.libvirt.org/page/VirtualNetworking

https://libvirt.org/formatdomain.html#tcp-tunnel

http://libvirt.org/formatdomain.html#multicast-tunnel

http://libvirt.org/formatdomain.html#udp-unicast-tunnel _(in Libvirt v1.2.20 and higher)_

Public Network interfaces are currently implemented using the macvtap driver.
The macvtap driver is only available with the Linux Kernel version >= 2.6.24.
See the following Libvirt documentation for the details of the macvtap usage.

http://www.libvirt.org/formatdomain.html#direct-attachment-to-physical-interface

An examples of network interface definitions:

```ruby
  # Private network using virtual network switching
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :private_network, :ip => "10.20.30.40"
  end

  # Private network using DHCP and a custom network
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :private_network,
      :type => "dhcp",
      :libvirt__network_address => '10.20.30.0'
  end

  # Private network (as above) using a domain name
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :private_network,
      :ip => "10.20.30.40",
      :libvirt__domain_name => "test.local"
  end

  # Private network. Point to Point between 2 Guest OS using a TCP tunnel
  # Guest 1
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :private_network,
      :libvirt__tunnel_type => 'server',
      # default is 127.0.0.1 if omitted
      # :libvirt__tunnel_ip => '127.0.0.1',
      :libvirt__tunnel_port => '11111'
    # network with ipv6 support
    test_vm1.vm.network :private_network,
      :ip => "10.20.5.42",
      :libvirt__guest_ipv6 => "yes",
      :libvirt__ipv6_address => "2001:db8:ca2:6::1",
      :libvirt__ipv6_prefix => "64"

  # Guest 2
  config.vm.define :test_vm2 do |test_vm2|
    test_vm2.vm.network :private_network,
      :libvirt__tunnel_type => 'client',
      # default is 127.0.0.1 if omitted
      # :libvirt__tunnel_ip => '127.0.0.1',
      :libvirt__tunnel_port => '11111'
    # network with ipv6 support
    test_vm2.vm.network :private_network,
      :ip => "10.20.5.45",
      :libvirt__guest_ipv6 => "yes",
      :libvirt__ipv6_address => "2001:db8:ca2:6::1",
      :libvirt__ipv6_prefix => "64"


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
private to Libvirt host only. It's not visible outside of the hypervisor box.

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

There is a way to pass specific options for Libvirt provider when using
`config.vm.network` to configure new network interface. Each parameter name
starts with `libvirt__` string. Here is a list of those options:

* `:libvirt__network_name` - Name of Libvirt network to connect to. By default,
  network 'default' is used.
* `:libvirt__netmask` - Used only together with `:ip` option. Default is
  '255.255.255.0'.
* `:libvirt__network_address` - Used only when `:type` is set to `dhcp`. Only `/24` subnet is supported. Default is `172.28.128.0`.
* `:libvirt__host_ip` - Address to use for the host (not guest).  Default is
  first possible address (after network address).
* `:libvirt__domain_name` - DNS domain of the DHCP server. Used only
  when creating new network.
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
* `:libvirt__tftp_root` - Path to the root directory served via TFTP.
* `:libvirt__adapter` - Number specifying sequence number of interface.
* `:libvirt__forward_mode` - Specify one of `veryisolated`, `none`, `open`, `nat`
  or `route` options.  This option is used only when creating new network. Mode
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
* `:libvirt__tunnel_ip` - Sets the source IP of the Libvirt tunnel interface.
  By default this is `127.0.0.1` for TCP and UDP tunnels and `239.255.1.1` for
  Multicast tunnels. It populates the address field in the `<source
  address="XXX">` of the interface xml configuration.
* `:libvirt__tunnel_port` - Sets the source port the tcp/udp/mcast tunnel with
  use. This port information is placed in the `<source port=XXX/>` section of
  interface xml configuration.
* `:libvirt__tunnel_local_port` - Sets the local port used by the udp tunnel
  interface type. It populates the port field in the `<local port=XXX">`
  section of the interface xml configuration. _(This feature only works in
  Libvirt 1.2.20 and higher)_
* `:libvirt__tunnel_local_ip` - Sets the local IP used by the udp tunnel
  interface type. It populates the ip entry of the `<local address=XXX">`
  section of the interface xml configuration. _(This feature only works in
  Libvirt 1.2.20 and higher)_
* `:libvirt__guest_ipv6` - Enable or disable guest-to-guest IPv6 communication.
  See [here](https://libvirt.org/formatnetwork.html#examplesPrivate6), and
  [here](http://libvirt.org/git/?p=libvirt.git;a=commitdiff;h=705e67d40b09a905cd6a4b8b418d5cb94eaa95a8)
  for for more information. *Note: takes either 'yes' or 'no' for value*
* `:libvirt__ipv6_address` - Define ipv6 address, require also prefix.
* `:libvirt__ipv6_prefix` - Define ipv6 prefix. generate string `<ip family="ipv6" address="address" prefix="prefix" >`
* `:libvirt__iface_name` - Define a name for the corresponding network interface
  created on the host. With this feature one can [simulate physical link
  failures](https://github.com/vagrant-libvirt/vagrant-libvirt/pull/498). Note
  that you cannot use names reserved for libvirt's usage based on [documentation](
  https://libvirt.org/formatdomain.html#overriding-the-target-element).
* `:libvirt__mac` - MAC address for the interface. *Note: specify this in lowercase
  since Vagrant network scripts assume it will be!*
* `:libvirt__mtu` - MTU size for the Libvirt network, if not defined, the
  created network will use the Libvirt default (1500). VMs still need to set the
  MTU accordingly.
* `:libvirt__model_type` - parameter specifies the model of the network adapter when you
  create a domain value by default virtio KVM believe possible values, see the
  documentation for Libvirt
* `:libvirt__driver_name` - Define which network driver to use. [More
  info](https://libvirt.org/formatdomain.html#setting-nic-driver-specific-options)
* `:libvirt__driver_queues` - Define a number of queues to be used for network
  interface. Set equal to number of vCPUs for best performance. [More
  info](http://www.linux-kvm.org/page/Multiqueue)
* `:autostart` - Automatic startup of network by the Libvirt daemon.
  If not specified the default is 'false'.
* `:libvirt__bus` - The bus of the PCI device. Both :bus and :slot have to be defined.
* `:libvirt__slot` - The slot of the PCI device. Both :bus and :slot have to be defined.
* `:libvirt__always_destroy` - Allow domains that use but did not create a
  network to destroy it when the domain is destroyed (default: `true`). Set to
  `false` to only allow the domain that created the network to destroy it.

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
  documentation](http://www.libvirt.org/formatdomain.html#direct-attachment-to-physical-interface).
  Default mode is 'bridge'.
* `:type` - is type of interface.(`<interface type="#{@type}">`)
* `:mac` - MAC address for the interface.
* `:network_name` - Name of Libvirt network to connect to.
* `:portgroup` - Name of Libvirt portgroup to connect to.
* `:ovs` - Support to connect to an Open vSwitch bridge device. Default is
  'false'.
* :ovs_interfaceid - Add Open vSwitch 'interfaceid' parameter.
* `:trust_guest_rx_filters` - Support trustGuestRxFilters attribute. Details
  are listed [here](http://www.libvirt.org/formatdomain.html#direct-attachment-to-physical-interface).
  Default is 'false'.
* `:libvirt__iface_name` - Define a name for the corresponding network interface
  that is created on the host connected to the bridge dev. This can be used to
  help attach VLAN tags to specific VMs by adjusting the pattern to match. Note
  that you cannot use names reserved for libvirt's usage based on [documentation](
  https://libvirt.org/formatdomain.html#overriding-the-target-element).
* `:libvirt__mtu` - MTU size for the Libvirt interface, if not defined, the
  created network will use the Libvirt default (1500). VMs still need to configure
  their internal interface MTUs.

Additionally for public networks, to facilitate validating if the device provided
can be used, vagrant-libvirt will check both the host interfaces visible to libvirt
and the existing networks for any existing bridge names. While some name patterns are
automatically excluded as presumed incorrect, if this pattern list is incorrect
it may be overridden by setting the option:
* `host_device_exclude_prefixes` - ignore any device starting with any of these
  string patterns as a valid bridge device for a public network definition.

### Management Network

vagrant-libvirt uses a private network to perform some management operations on
VMs. All VMs will have an interface connected to this network and an IP address
dynamically assigned by Libvirt unless you set `:mgmt_attach` to 'false'.
This is in addition to any networks you configure. The name and address
used by this network are configurable at the provider level.

* `management_network_name` - Name of Libvirt network to which all VMs will be
  connected. If not specified the default is 'vagrant-libvirt'.
* `management_network_address` - Address of network to which all VMs will be
  connected. Must include the address and subnet mask. If not specified the
  default is '192.168.121.0/24'.
* `management_network_mode` - Network mode for the Libvirt management network.
  Specify one of veryisolated, none, open, nat or route options. Further
  documented under [Private Networks](#private-network-options)
* `management_network_guest_ipv6` - Enable or disable guest-to-guest IPv6
  communication. See
  [here](https://libvirt.org/formatnetwork.html#examplesPrivate6), and
  [here](http://libvirt.org/git/?p=libvirt.git;a=commitdiff;h=705e67d40b09a905cd6a4b8b418d5cb94eaa95a8)
  for for more information.
* `management_network_autostart` - Automatic startup of mgmt network, if not
  specified the default is 'false'.
* `management_network_pci_bus` -  The bus of the PCI device.
* `management_network_pci_slot` -  The slot of the PCI device.
* `management_network_mac` - MAC address of management network interface.
* `management_network_domain` - Domain name assigned to the management network.
* `management_network_mtu` - MTU size of management network. If not specified,
  the Libvirt default (1500) will be used.
* `management_network_keep` - Starting from version *0.7.0*, *always_destroy* is set to *true* by default for any network.
  This option allows to change this behaviour for the management network.
* `management_network_iface_name` - Allow controlling of the network device name that appears on the host for the management network, same as `:libvirt__iface_name` for public and private network definitions. (unreleased).
* `management_network_model_type` - Model of the network adapter to use for the management interface. Default is `nic_model_type`, which in turn defaults to 'virtio'.

You may wonder how vagrant-libvirt knows the IP address a VM received.  Libvirt
doesn't provide a standard way to find out the IP address of a running domain.
But we do know the MAC address of the virtual machine's interface on the
management network. Libvirt is closely connected with dnsmasq, which acts as a
DHCP server. dnsmasq writes lease information in the `/var/lib/libvirt/dnsmasq`
directory. Vagrant-libvirt looks for the MAC address in this file and extracts
the corresponding IP address.

It is also possible to use the Qemu Agent to extract the management interface
configuration from the booted virtual machine. This is helpful in libvirt
environments where no local dnsmasq is used for automatic address assignment,
but external dhcp services via bridged libvirt networks.

Prerequisite is to enable the qemu agent channel via ([Libvirt communication
channels](#libvirt-communication-channels)) and the virtual machine image must
have the agent pre-installed before deploy. The agent will start automatically
if it detects an attached channel during boot.

* `qemu_use_agent` - false by default, if set to true, attempt to extract configured
  ip address via qemu agent.

By default if `qemu_use_agent` is set to `true` the code will automatically
inject a suitable channel unless there already exists an entry with a
`:target_name` matching `'org.qemu.guest_agent.'`.
Alternatively if setting `qemu_use_agent` but, needing to disable the addition
of the channel, simply use a disabled flag as follows:
```ruby
Vagrant.configure(2) do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :disabled => true
  end
end
```

To use the management network interface with an external dhcp service you need
to setup a bridged host network manually and define it via
`management_network_name` in your Vagrantfile.

## Additional Disks

You can create and attach additional disks to a VM via `libvirt.storage :file`.
It has a number of options:

* `path` - Location of the disk image. If unspecified, a path is automatically
  chosen in the same storage pool as the VMs primary disk.
* `device` - Name of the device node the disk image will have in the VM, e.g.
  *vdb*. If unspecified, the next available device is chosen.
* `size` - Size of the disk image. If unspecified, defaults to 10G.
* `type` - Type of disk image to create. Defaults to *qcow2*.
* `bus` - Type of bus to connect device to. Defaults to *virtio*.
* `allow_existing` - Set to true if you want to allow the VM to use a
  pre-existing disk. If the disk doesn't exist it will be created.
  Disks with this option set to true need to be removed manually.
* `shareable` - Set to true if you want to simulate shared SAN storage.
* `serial` - Serial number of the disk device.
* `wwn` - WWN number of the disk device.

The following disk performance options can also be configured
(see the [libvirt documentation for possible values](http://libvirt.org/formatdomain.html#hard-drives-floppy-disks-cdroms)
or [here](https://www.suse.com/documentation/sles11/book_kvm/data/sect1_chapter_book_kvm.html) for a fuller explanation).
In all cases, the options use the hypervisor default if not specified, or if set to `nil`.

* `cache` - Cache mode to use. Value may be `default`, `none`, `writeback`, `writethrough`, `directsync` or `unsafe`.
* `io` - Controls specific policies on I/O. Value may be `threads` or `native`.
* `copy_on_read` - Controls whether to copy read backing file into the image file. Value may be `on` or `off`.
* `discard` - Controls whether discard requests (also known as "trim" or "unmap") are ignored or passed to the filesystem. Value may be `unmap` or `ignore`.
  Note: for discard to work, you will likely also need to set `:bus => 'scsi'`
* `detect_zeroes` - Controls whether to detect zero write requests. Value may be `off`, `on` or `unmap`.

The following example creates two additional disks.

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.storage :file, :size => '20G'
    libvirt.storage :file, :size => '40G', :bus => 'scsi', :type => 'raw', :discard => 'unmap', :detect_zeroes => 'on'
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
  of additional disk definition becomes irrelevant.

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

## Floppies

You can attach up to two floppies to a VM via `libvirt.storage :file,
:device => :floppy`. Available options are:

* `path` - The path to the vfd image to be used for the floppy drive.
* `dev` - The device to use (`fda` or `fdb`). This will be
  automatically determined if unspecified.

The following example creates a floppy drive in the VM:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.storage :file, :device => :floppy, :path => '/path/to/floppy.vfs'
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
required, except domain, which defaults to `0x0000`:

* `domain` - The domain of the PCI device
* `bus` - The bus of the PCI device
* `slot` - The slot of the PCI device
* `function` - The function of the PCI device

You can extract that information from output of `lspci` command. First
characters of each line are in format `[<domain>]:[<bus>]:[<slot>].[<func>]`. For example:

```shell
$ lspci| grep NVIDIA
0000:03:00.0 VGA compatible controller: NVIDIA Corporation GK110B [GeForce GTX TITAN Black] (rev a1)
```

In that case `domain` is `0x0000`, `bus` is `0x03`, `slot` is `0x00` and `function` is `0x0`.

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.pci :domain => '0x0000', :bus => '0x06', :slot => '0x12', :function => '0x5'

    # Add another one if it is necessary
    libvirt.pci :domain => '0x0000', :bus => '0x03', :slot => '0x00', :function => '0x0'
  end
end
```

Note! Above options affect configuration only at domain creation. It won't change VM behaviour on `vagrant reload` after domain was created.

Don't forget to [set](#domain-specific-options) `kvm_hidden` option to `true` especially if you are passthroughing NVIDIA GPUs. Otherwise GPU is visible from VM but cannot be operated.


## Using USB Devices

There are several ways to pass a USB device through to a running instance:
* Use `libvirt.usb` to [attach a USB device at boot](#usb-device-passthrough), with the device ID specified in the Vagrantfile
* Use a client (such as `virt-viewer` or `virt-manager`) to attach the device at runtime [via USB redirectors](#usb-redirector-devices)
* Use `virsh attach-device` once the VM is running (however, this is outside the scope of this readme)

In all cases, if you wish to use a high-speed USB device,
you will need to use `libvirt.usb_controller` to specify a USB2 or USB3 controller,
as the default configuration only exposes a USB1.1 controller.

### USB Controller Configuration

The USB controller can be configured using `libvirt.usb_controller`, with the following options:

* `model` - The USB controller device model to emulate. (mandatory)
* `ports` - The number of devices that can be connected to the controller.

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Set up a USB3 controller
    libvirt.usb_controller :model => "qemu-xhci"
  end
end
```

See the [libvirt documentation](https://libvirt.org/formatdomain.html#controllers) for a list of valid models.

If any USB devices are passed through by setting `libvirt.usb` or `libvirt.redirdev`, a default controller will be added using the model `qemu-xhci` in the absence of a user specified one. This should help ensure more devices work out of the box as the default configured by libvirt is pii3-uhci, which appears to only work for USB 1 devices and does not work as expected when connected via a USB 2 controller, while the xhci stack should work for all versions of USB.

### USB Device Passthrough

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

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # pass through specific device based on identifying it
    libvirt.usb :vendor => '0x1234', :product => '0xabcd'
    # pass through a host device where multiple of the same vendor/product exist
    libvirt.usb :bus => '1', :device => '1'
  end
end
```

Additionally, the following options can be used:

* `startupPolicy` - Is passed through to Libvirt and controls if the device has
  to exist.  Libvirt currently allows the following values: "mandatory",
  "requisite", "optional".


### USB Redirector Devices
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

Note that in order to enable USB redirection with Spice clients,
you may need to also set `libvirt.graphics_type = "spice"`

#### Filter for USB Redirector Devices
You can define filter for redirected devices. These filters can be positive or negative, by setting the mandatory option `allow=yes` or `allow=no`. All available options are listed below. Note the option `allow` is mandatory.

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
    libvirt.redirfilter :class => "0x0b", :vendor => "0x08e6", :product => "0x3437", :version => "2.00", :allow => "yes"
    libvirt.redirfilter :allow => "no"
  end
end
```

## Serial Console Devices
You can define settings to redirect output from the serial console of any VM brought up with libvirt to a file or other devices that are listening. [See libvirt documentation](https://libvirt.org/formatdomain.html#serial-port).

Currently only redirecting to a file is supported.

* `type` - only value that has an effect is file, in the future support may be added for virtual console, pty, dev, pipe, tcp, udp, unix socket, spiceport & nmdm.
* `source` - options pertaining to how the connection attaches to the host, contains sub-settings dependent on `type`.
  `source` options for type `file`
  * `path` - file on host to connect to the serial port to record all output. May be created by qemu system user causing some permissions issues.

```ruby
Vagrant.configure("2") do |config|
  config.vm.define :test do |test|
    test.vm.provider :libvirt do |domain|
      domain.serial :type => "file", :source => {:path => "/var/log/vm_consoles/test.log"}
    end
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

## Watchdog device
A virtual hardware watchdog device can be added to the guest via the `libvirt.watchdog` element. The option `model` is mandatory and could have on of the following values.

* `i6300esb` - the recommended device, emulating a PCI Intel 6300ESB
* 'ib700` - emulating an ISA iBase IB700
* `diag288` - emulating an S390 DIAG288 device

The optional action attribute describes what `action` to take when the watchdog expires. Valid values are specific to the underlying hypervisor. The default behavior is `reset`.

* `reset` - default, forcefully reset the guest
* `shutdown` - gracefully shutdown the guest (not recommended)
* `poweroff` - forcefully power off the guest
* `pause` - pause the guest
* `none` - do nothing
* `dump` - automatically dump the guest
* `inject-nmi` - inject a non-maskable interrupt into the guest

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Add Libvirt watchdog device model i6300esb
    libvirt.watchdog :model => 'i6300esb', :action => 'reset'
  end
end
```

## Smartcard device
A virtual smartcard device can be supplied to the guest via the `libvirt.smartcard` element. The option `mode` is mandatory and currently only value `passthrough` is supported. The value `spicevmc` for option `type` is default value and can be suppressed. On using `type = tcp`, the options `source_mode`, `source_host` and `source_service` are mandatory.

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Add smartcard device with type 'spicevmc'
    libvirt.smartcard :mode => 'passthrough', :type => 'spicevmc'
  end
end
```

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Add smartcard device with type 'tcp'
    domain.smartcard :mode => 'passthrough', :type => 'tcp', :source_mode => 'bind', :source_host => '127.0.0.1', :source_service => '2001'
  end
end
```
## Hypervisor Features

Hypervisor features can be specified via `libvirt.features` as a list. The default
options that are enabled are `acpi`, `apic` and `pae`. If you define `libvirt.features`
you overwrite the defaults, so keep that in mind.

An example:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Specify the default hypervisor features
    libvirt.features = ['acpi', 'apic', 'pae' ]
  end
end
```

A different example for ARM boards:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Specify the default hypervisor features
    libvirt.features = ["apic", "gic version='2'" ]
  end
end
```

You can also specify a special set of features that help improve the behavior of guests
running Microsoft Windows.

You can specify HyperV features via `libvirt.hyperv_feature`. Available
options are listed below. Note that both options are required:

* `name` - The name of the feature Hypervisor feature (see Libvirt doc)
* `state` - The state for this feature which can be either `on` or `off`.

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Relax constraints on timers
    libvirt.hyperv_feature :name => 'relaxed', :state => 'on'
    # Enable virtual APIC
    libvirt.hyperv_feature :name => 'vapic', :state => 'on'
    # Enable spinlocks (requires retries to be specified)
    libvirt.hyperv_feature :name => 'spinlocks', :state => 'on', :retries => '8191'
  end
end
```

## Clock

The clock can be configured using one of the following methods:

* Set nothing, and the clock will default to UTC.
* Set `libvirt.clock_offset` to 'utc' or 'localtime' by assigning the respective values.
* To set the clock to a different timezone, assign the timezone name to `libvirt.clock_timezone`.
* To set the clock to the same absolute time whenever the VM starts, set `libvirt.clock_absolute`.
  The value format is that of an epoch timestamp.
* To set the clock at an arbitrary offset to realtime, use `libvirt.clock_adjustment`.
  Specify the offset adjustment in seconds.  By default, the clock offset is relative to UTC,
  but this can be changed by setting `libvirt.clock_basis` to 'localtime'.

In addition to the above, timers can be specified via `libvirt.clock_timer`.
Available options for timers are: name, track, tickpolicy, frequency, mode,  present

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Set clock offset to localtime
    libvirt.clock_offset = 'localtime'
    # Timers ...
    libvirt.clock_timer :name => 'rtc', :tickpolicy => 'catchup'
    libvirt.clock_timer :name => 'pit', :tickpolicy => 'delay'
    libvirt.clock_timer :name => 'hpet', :present => 'no'
    libvirt.clock_timer :name => 'hypervclock', :present => 'yes'
  end
end
```

## CPU features

You can specify CPU feature policies via `libvirt.cpu_feature`. Available
options are listed below. Note that both options are required:

* `name` - The name of the feature for the chosen CPU (see Libvirt's
  `cpu_map.xml`)
* `policy` - The policy for this feature (one of `force`, `require`,
  `optional`, `disable` and `forbid` - see Libvirt documentation)

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

## Memory Backing

You can specify memoryBacking options via `libvirt.memorybacking`. Available options are shown below. Full documentation is available at the [libvirt _memoryBacking_ section](https://libvirt.org/formatdomain.html#memory-backing).

NOTE: The hugepages `<page>` element is not yet supported

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.memorybacking :hugepages
    libvirt.memorybacking :nosharepages
    libvirt.memorybacking :locked
    libvirt.memorybacking :source, :type => 'file'
    libvirt.memorybacking :access, :mode => 'shared'
    libvirt.memorybacking :allocation, :mode => 'immediate'
  end
end
```
