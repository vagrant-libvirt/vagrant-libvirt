# 0.0.9 (September 29, 2013)

* fixed version of nokogiri = 1.5.10(by Brian Pitts <brian@polibyte.com>)
* fix issue with network activation (by Brian Pitts <brian@polibyte.com>)
* restrict version of vagrant > 1.3.0

# 0.0.8 (September 25, 2013)

* enable parallelization (by Brian Pitts <brian@polibyte.com>)

# 0.0.7

* Fixed namespace collision with ruby-libvirt library which used by
  vagrant-kvm provider.(by Hiroshi Miura)
* enable nested virtualization for amd (by Jordan Tardif <jordan@dreamhost.com>)

# 0.0.6 (Jul 24, 2013)

* Synced folder via NFS support.
* Routed private network support.
* Configurable ssh parameters in Vagrantfile via `config.ssh.*`.
* Fixed uploading base box image to storage pool bug (buffer was too big).

# 0.0.5 (May 10, 2013)

* Private networks support.
* Creating new private networks if ip is specified and network is not
  available.
* Removing previously created networks, if there are no active connections.
* Guest interfaces configuration.
* Setting guest hostname (via `config.vm.hostname`).

# 0.0.4 (May 5, 2013)

* Bug fix in number of parameters for provisioner.
* Handle box URL when downloading a box.
* Support for running ssh commands like `vagrant ssh -c "bash cli"`

# 0.0.3 (Apr 11, 2013)

* Cpu and memory settings for domains.
* IP is parsed from dnsmasq lease files only, no saving of IP address into
  files anymore.
* Tool for preparation RedHat Linux distros for box image added.

# 0.0.2 (Apr 1, 2013)

* Halt, suspend, resume, ssh and provision commands added.
* IP address of VM is saved into `$data_dir/ip` file.
* Provider can be set via `VAGRANT_DEFAULT_PROVIDER` env variable.

# 0.0.1 (Mar 26, 2013)

* Initial release.
