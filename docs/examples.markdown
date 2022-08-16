---
title: Examples
nav_order: 5
toc: true
---

Examples of specific use cases, and/or in-depth configuration for special behaviour.

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

Example for vm with 2 networks and only 1 is bootable and has dhcp server in this subnet, for example foreman with dhcp server
Name of network "foreman_managed" is key for define boot order
```ruby
    config.vm.define :pxeclient do |pxeclient|
      pxeclient.vm.network :private_network,ip: '10.0.0.5',
            libvirt__network_name: "foreman_managed",
            libvirt__dhcp_enabled: false,
            libvirt__host_ip: '10.0.0.1'

       pxeclient.vm.provider :libvirt do |domain|
          domain.memory = 1000
          boot_network = {'network' => 'foreman_managed'}
          domain.storage :file, :size => '100G', :type => 'qcow2'
          domain.boot boot_network
          domain.boot 'hd'
        end
      end
```

An example VM that is PXE booted from the `br1` device (which must already be configured in the host machine), and if that fails, is booted from the disk:

```ruby
Vagrant.configure("2") do |config|
  config.vm.define :pxeclient do |pxeclient|
    pxeclient.vm.network :public_network,
      dev: 'br1',
      auto_config: false
    pxeclient.vm.provider :libvirt do |domain|
      boot_network = {'dev' => 'br1'}
      domain.storage :file, :size => '100G'
      domain.boot boot_network
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
If your VM should happen to be rebooted, the SSH session will need to be
re-established by halting the VM and bringing it back up.

vagrant-libvirt supports an additional `forwarded_port` option `gateway_ports`
which defaults to `false`, but can be set to `true` if you want the forwarded
port to be accessible from outside the Vagrant host.  In this case you should
also set the `host_ip` option to `'*'` since it defaults to `'localhost'`.

You can also provide a custom adapter to forward from by 'adapter' option.
Default is `eth0`.

**Internally Accessible Port Forward**

`config.vm.network :forwarded_port, guest: 80, host: 2000`

**Externally Accessible Port Forward**

`config.vm.network :forwarded_port, guest: 80, host: 2000, host_ip: "0.0.0.0"`

## Forwarding the ssh-port

Vagrant-libvirt now supports forwarding the standard ssh-port on port 2222 from
the localhost to allow for consistent provisioning steps/ports to be used when
defining across multiple providers.

To enable, set the following:
```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Enable forwarding of forwarded_port with id 'ssh'.
    libvirt.forward_ssh_port = true
  end
end
```

Previously by default libvirt skipped the forwarding of the ssh-port because
you can access the machine directly. In the future it is expected that this
will be enabled by default once autocorrect support is added to handle port
collisions for multi machine environments gracefully.

## Synced Folders

Vagrant automatically syncs the project folder on the host to `/vagrant` in
the guest. You can also configure additional synced folders.

**SECURITY NOTE:** for remote Libvirt, nfs synced folders requires a bridged
public network interface and you must connect to Libvirt via ssh.

**NFS**

`vagrant-libvirt` supports
[NFS](https://www.vagrantup.com/docs/synced-folders/nfs) as default with
bidirectional synced folders.

Example with NFS:

``` ruby
Vagrant.configure("2") do |config|
  config.vm.synced_folder "./", "/vagrant"
end
```

**RSync**

`vagrant-libvirt` supports
[rsync](https://www.vagrantup.com/docs/synced-folders/rsync) with
unidirectional synced folders.

Example with rsync:

``` ruby
Vagrant.configure("2") do |config|
  config.vm.synced_folder "./", "/vagrant", type: "rsync"
end
```

**9P**

`vagrant-libvirt` supports [VirtFS](http://www.linux-kvm.org/page/VirtFS) ([9p
or Plan 9](https://en.wikipedia.org/wiki/9P_\(protocol\))) with bidirectional
synced folders.

Difference between NFS and 9p is explained
[here](https://unix.stackexchange.com/questions/240281/virtfs-plan-9-vs-nfs-as-tool-for-share-folder-for-virtual-machine).

For 9p shares, a `mount: false` option allows to define synced folders without
mounting them at boot.

Example for `accessmode: "squash"` with 9p:

``` ruby
Vagrant.configure("2") do |config|
  config.vm.synced_folder "./", "/vagrant", type: "9p", disabled: false, accessmode: "squash", owner: "1000"
end
```

Example for `accessmode: "mapped"` with 9p:

``` ruby
Vagrant.configure("2") do |config|
  config.vm.synced_folder "./", "/vagrant", type: "9p", disabled: false, accessmode: "mapped", mount: false
end
```

Further documentation on using 9p can be found in [kernel
docs](https://www.kernel.org/doc/Documentation/filesystems/9p.txt) and in
[QEMU
wiki](https://wiki.qemu.org/Documentation/9psetup#Starting_the_Guest_directly).

Please do note that 9p depends on support in the guest and not all distros
come with the 9p module by default.

**Virtio-fs**

`vagrant-libvirt` supports [Virtio-fs](https://virtio-fs.gitlab.io/) with
bidirectional synced folders.

For virtiofs shares, a `mount: false` option allows to define synced folders
without mounting them at boot.

So far, passthrough is the only supported access mode and it requires running
the virtiofsd daemon as root.

QEMU needs to allocate the backing memory for all the guest RAM as shared
memory, e.g. [Use file-backed
memory](https://libvirt.org/kbase/virtiofs.html#host-setup) by enable
`memory_backing_dir` option in `/etc/libvirt/qemu.conf`:

``` shell
memory_backing_dir = "/dev/shm"
```

Example for Libvirt \>= 6.2.0 (e.g. Ubuntu 20.10 with Linux 5.8.0 + QEMU 5.0 +
Libvirt 6.6.0, i.e. NUMA nodes required) with virtiofs:

``` ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.cpus = 2
    libvirt.numa_nodes = [{ :cpus => "0-1", :memory => 8192, :memAccess => "shared" }]
    libvirt.memorybacking :access, :mode => "shared"
  end
  config.vm.synced_folder "./", "/vagrant", type: "virtiofs"
end
```

Example for Libvirt \>= 6.9.0 (e.g. Ubuntu 21.04 with Linux 5.11.0 + QEMU 5.2 +
Libvirt 7.0.0, or Ubuntu 20.04 + [PPA
enabled](https://launchpad.net/~savoury1/+archive/ubuntu/virtualisation)) with
virtiofs:

``` ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.cpus = 2
    libvirt.memory = 8192
    libvirt.memorybacking :access, :mode => "shared"
  end
  config.vm.synced_folder "./", "/vagrant", type: "virtiofs"
end
```

Further documentation on using virtiofs can be found in [official
HowTo](https://virtio-fs.gitlab.io/index.html#howto) and in [Libvirt
KB](https://libvirt.org/kbase/virtiofs.html).

Please do note that virtiofs depends on:

  - Host: Linux \>= 5.4, QEMU \>= 4.2 and Libvirt \>= 6.2 (e.g. Ubuntu 20.10)
  - Guest: Linux \>= 5.4 (e.g. Ubuntu 20.04)

## QEMU Session Support

vagrant-libvirt supports using QEMU user sessions to maintain Vagrant VMs. As the session connection does not have root access to the system features which require root will not work. Access to networks created by the system QEMU connection can be granted by using the [QEMU bridge helper](https://wiki.qemu.org/Features/HelperNetworking). The bridge helper is enabled by default on some distros but may need to be enabled/installed on others.

There must be a virbr network defined in the QEMU system session. The libvirt `default` network which comes by default, the vagrant `vagrant-libvirt` network which is generated if you run a Vagrantfile using the System session, or a manually defined network can be used. These networks can be set to autostart with `sudo virsh net-autostart <net-name>`, which'll mean no further root access is required even after reboots.

The QEMU bridge helper is configured via `/etc/qemu/bridge.conf`. This file must include the virbr you wish to use (e.g. virbr0, virbr1, etc). You can find this out via `sudo virsh net-dumpxml <net-name>`.
```
allow virbr0
```

An example configuration of a machine using the QEMU session connection:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    # Use QEMU session instead of system connection
    libvirt.qemu_use_session = true
    # URI of QEMU session connection, default is as below
    libvirt.uri = 'qemu:///session'
    # URI of QEMU system connection, use to obtain IP address for management, default is below
    libvirt.system_uri = 'qemu:///system'
    # Path to store Libvirt images for the virtual machine, default is as ~/.local/share/libvirt/images
    libvirt.storage_pool_path = '/home/user/.local/share/libvirt/images'
    # Management network device, default is below
    libvirt.management_network_device = 'virbr0'
  end

  # Public network configuration using existing network device
  # Note: Private networks do not work with QEMU session enabled as root access is required to create new network devices
  config.vm.network :public_network, :dev => "virbr1",
      :mode => "bridge",
      :type => "bridge"
end
```

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

To passthrough a hardware TPM, you will generally only need to modify the
`tpm_path` variable in your guest configuration. However, advanced usage,
such as the application of a Software TPM, may require modifying the
`tpm_model`, `tpm_type` and `tpm_version` variables.

The TPM options will only be used if you specify a TPM path or version.
Declarations of any TPM options without specifying a path or version will
result in those options being ignored.

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

It's also possible for Libvirt to start an emulated TPM device on the host.
Requires `swtpm` and `swtpm-tools`

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.tpm_model = "tpm-crb"
    libvirt.tpm_type = "emulator"
    libvirt.tpm_version = "2.0"
  end
end
```

## SMBIOS System Information

Libvirt allows to specify
[SMBIOS System Information](https://libvirt.org/formatdomain.html#smbios-system-information)
like a base board or chassis manufacturer or a system serial number.

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.sysinfo = {
      'bios': {
        'vendor': 'Test Vendor',
        'version': '0.1.2',
      },
      'system': {
        'manufacturer': 'Test Manufacturer',
        'version': '0.1.0',
        'serial': '',
      },
      'base board': {
        'manufacturer': 'Test Manufacturer',
        'version': '1.2',
      },
      'chassis': {
        'manufacturer': 'Test Manufacturer',
        'serial': 'AABBCCDDEE',
      },
      'oem strings': [
        'app1: string1',
        'app1: string2',
        'app2: string1',
        'app2: string2',
      ],
    }
  end
end
```

## Memory balloon

The configuration of the memory balloon device can be overridden. By default,
libvirt will automatically attach a memory balloon; this behavior is preserved
by not configuring any memballoon-related options. The memory balloon can be
explicitly disabled by setting `memballoon_enabled` to `false`. Setting
`memballoon_enabled` to `true` will allow additional configuration of
memballoon-related options.

Here is an example of using the memballoon options:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.memballoon_enabled = true
    libvirt.memballoon_model = 'virtio'
    libvirt.memballoon_pci_bus = '0x00'
    libvirt.memballoon_pci_slot = '0x0f'
  end
end
```

## Libvirt communication channels

For certain functionality to be available within a guest, a private
communication channel must be established with the host. Two notable examples
of this are the QEMU guest agent, and the Spice/QXL graphics type.

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
we create 3 VMs with the following configuration:

* **controller**: No channel settings specified, so we default to the provider
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
  config.vm.box = "fedora/32-cloud-base"
  config.vm.provider :libvirt do |libvirt|
    libvirt.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
  end

  config.vm.define "controller" do |controller|
    controller.vm.provider :libvirt do |domain|
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

## Custom QEMU arguments and environment variables

You can also specify multiple qemuargs arguments or qemuenv environment variables for qemu-system

* `value` - Value

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.qemuargs :value => "-device"
    libvirt.qemuargs :value => "intel-iommu"
    libvirt.qemuenv QEMU_AUDIO_DRV: 'pa'
    libvirt.qemuenv QEMU_AUDIO_TIMER_PERIOD: '150'
    libvirt.qemuenv QEMU_PA_SAMPLES: '1024', QEMU_PA_SERVER: '/run/user/1000/pulse/native'
  end
end
```
