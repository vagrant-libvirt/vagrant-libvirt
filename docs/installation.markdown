---
title: Installation
nav_order: 2
toc: true
---

## Requirements

* [Libvirt](http://libvirt.org) - should work with version 1.5 or newer
* [Vagrant](http://www.vagrantup.com) - plugin attempts to support all since 1.5
* [GCC](https://gcc.gnu.org/install/) and [Make](https://www.gnu.org/software/make/) - used to compile native versions of ruby-libvirt and nokogiri when using upstream Vagrant

While we only test with upstream vagrant installed as a gem, we recommend that you install
vagrant as provided by your distribution as installing vagrant-libvirt involves linking between
libvirt (ruby-libvirt) and the ruby installation used by vagrant. Since upstream vagrant
provides an embedded ruby, this typically causes issues with missing symbols between libraries
included and what is expected by libvirt for the ruby bindings linking to work.

First, you should have both QEMU and Libvirt installed if you plan to run VMs on your
local system. For instructions, refer to your Linux distribution's documentation. Suggested
packages are provided in our guides for as a quick reference

{: .warning }
Before you start using vagrant-libvirt, please make sure your Libvirt
and QEMU installation is working correctly and you are able to create QEMU or
KVM type virtual machines with `virsh` or `virt-manager`.

Next, you must have Vagrant installed from your distribution packages.
Vagrant-libvirt supports Vagrant 2.0, 2.1 & 2.2. It should also work with earlier
releases from 1.5 onwards but they are not actively tested.

{% assign repo = site.github.public_repositories | where: "name", site.github.repository_name %}
Check the [unit tests](https://github.com/vagrant-libvirt/vagrant-libvirt/blob/{{ repo.first.default_branch }}/.github/workflows/unit-tests.yml)
for the current list of tested versions.

If there is no distribution package or you wish to use the upstream vagrant, you may wish to use
the our [QA installation script](https://github.com/vagrant-libvirt/vagrant-libvirt-qa/blob/main/scripts/install.bash)
to install both vagrant and vagrant-libvirt
Alternatively you may follow
[vagrant installation instructions](http://docs.vagrantup.com/v2/installation/index.html) along
with the manual instructions for what packages to install where indicated for upstream vagrant below.
In some cases the vagrant version for the distribution may be running with a sufficiently old ruby
that it is difficult to install the required dependencies and you will need to use the upstream.


## Guides

### Docker / Podman

Due to the number of issues encountered around compatibility between the ruby runtime environment
that is part of the upstream vagrant installation and the library dependencies of libvirt that
this project requires to communicate with libvirt, there is a docker image built and published.

This should allow users to execute vagrant with vagrant-libvirt without needing to deal with
the compatibility issues, though you may need to extend the image for your own needs should
you make use of additional plugins.

{: .info }
The default image contains the full toolchain required to build and install vagrant-libvirt
and it's dependencies. There is also a smaller image published with the `-slim` suffix if you
just need vagrant-libvirt and don't need to install any additional plugins for your environment.

If you are connecting to a remote system libvirt, you may omit the
`-v /var/run/libvirt/:/var/run/libvirt/` mount bind. Some distributions patch the local
vagrant environment to ensure vagrant-libvirt uses `qemu:///session`, which means you
may need to set the environment variable `LIBVIRT_DEFAULT_URI` to the same value if
looking to use this in place of your distribution provided installation.

#### Using Docker

To get the image with the most recent release:
```bash
docker pull vagrantlibvirt/vagrant-libvirt:latest
```

<div class="info">If you want the very latest code you can use the <code class="language-plaintext highlighter-rouge">edge</code> tag instead.
<div class="language-bash highlighter-rouge" style="margin-top: 1em; margin-bottom: 0;"><div class="highlight"><pre class="highlight">
<code>docker pull vagrantlibvirt/vagrant-libvirt:edge</code>
</pre></div></div>
</div>

Running the image:
```bash
docker run -i --rm \
  -e LIBVIRT_DEFAULT_URI \
  -v /var/run/libvirt/:/var/run/libvirt/ \
  -v ~/.vagrant.d:/.vagrant.d \
  -v $(realpath "${PWD}"):${PWD} \
  -w $(realpath "${PWD}") \
  --network host \
  vagrantlibvirt/vagrant-libvirt:latest \
    vagrant status
```

It's possible to define a function in `~/.bashrc`, for example:
```bash
vagrant(){
  docker run -i --rm \
    -e LIBVIRT_DEFAULT_URI \
    -v /var/run/libvirt/:/var/run/libvirt/ \
    -v ~/.vagrant.d:/.vagrant.d \
    -v $(realpath "${PWD}"):${PWD} \
    -w $(realpath "${PWD}") \
    --network host \
    vagrantlibvirt/vagrant-libvirt:latest \
      vagrant $@
}

```

#### Using Podman

Preparing the podman run, only once:

```bash
mkdir -p ~/.vagrant.d/{boxes,data,tmp}
```
_N.B. This is needed until the entrypoint works for podman to only mount the `~/.vagrant.d` directory_

To run with Podman you need to include

```bash
  --entrypoint /bin/bash \
  --security-opt label=disable \
  -v ~/.vagrant.d/boxes:/vagrant/boxes \
  -v ~/.vagrant.d/data:/vagrant/data \
  -v ~/.vagrant.d/tmp:/vagrant/tmp \
```

for example:

```bash
vagrant(){
  podman run -it --rm \
    -e LIBVIRT_DEFAULT_URI \
    -v /var/run/libvirt/:/var/run/libvirt/ \
    -v ~/.vagrant.d/boxes:/vagrant/boxes \
    -v ~/.vagrant.d/data:/vagrant/data \
    -v ~/.vagrant.d/tmp:/vagrant/tmp \
    -v $(realpath "${PWD}"):${PWD} \
    -w $(realpath "${PWD}") \
    --network host \
    --entrypoint /bin/bash \
    --security-opt label=disable \
    docker.io/vagrantlibvirt/vagrant-libvirt:latest \
      vagrant $@
}
```

Running Podman in rootless mode maps the root user inside the container to your host user so we need to bypass [entrypoint.sh](https://github.com/vagrant-libvirt/vagrant-libvirt/blob/master/entrypoint.sh) and mount persistent storage directly to `/vagrant`. 

#### Extending the container image with additional vagrant plugins

By default the image published and used contains the entire tool chain required
to reinstall the vagrant-libvirt plugin and it's dependencies, as this is the
default behaviour of vagrant anytime a new plugin is installed. This means it
should be possible to use a simple `FROM` statement and ask vagrant to install
additional plugins.

```
FROM vagrantlibvirt/vagrant-libvirt:latest

RUN vagrant plugin install <plugin>
```

### Ubuntu / Debian

{: .info }
You may need to modify your `sources.list` to uncomment the deb-src entries where using build-dep commands below.

#### Ubuntu 18.10, Debian 9 and up

* Distro Vagrant
```shell
sudo apt-get install -y qemu libvirt-daemon-system ebtables libguestfs-tools
sudo apt-get install --no-install-recommends -y vagrant ruby-fog-libvirt
vagrant plugin install vagrant-libvirt
```

{% include upstream-vagrant-install.html distro="ubuntu" -%}
And subsequently install remaining dependencies and plugin:
```shell
sudo apt-get build-dep vagrant ruby-libvirt
sudo apt-get install -y qemu libvirt-daemon-system ebtables libguestfs-tools \
    libxslt-dev libxml2-dev zlib1g-dev ruby-dev
vagrant plugin install vagrant-libvirt
```

#### Ubuntu 18.04, Debian 8 and older

{: .warn }
This has been kept for historical reasons, however only Ubuntu 18.04 is supported due to LTS, please
consider all other versions unsupported.

{% include upstream-vagrant-install.html distro="debian" content=distro_deps -%}
And subsequently install remaining dependencies and plugin:
```shell
sudo apt-get build-dep vagrant ruby-libvirt
sudo apt-get install -y qemu libvirt-bin ebtables libguestfs-tools \
    libxslt-dev libxml2-dev zlib1g-dev ruby-dev
vagrant plugin install vagrant-libvirt
```

* Distro Vagrant
```shell
sudo apt-get install -y qemu libvirt-bin ebtables libguestfs-tools
sudo apt-get install --no-install-recommends -y vagrant ruby-fog-libvirt
vagrant plugin install vagrant-libvirt
```

   {: .warn }
   Unless you can can install a newer ruby on Debian 8, it is likely that the distro vagrant approach will not be straight forward as vagrant-libvirt requires a fog-core and fog-libvirt releases that depend on ruby 2.5 or newer.

### Fedora

#### Fedora 32 and newer

{: .info }
Due to the involved nature of getting the linking to work correctly when using the upstream
vagrant, it is strongly recommended to either use the distro packaged vagrant, or the
install script from the vagrant-libvirt-qa approach.

* Distro Vagrant
```shell
plugin_deps=($(sudo dnf repoquery --depends vagrant-libvirt 2>/dev/null | cut -d' ' -f1))
dependencies=$(sudo dnf repoquery --qf "%{name}" ${plugin_deps[@]/#/--whatprovides })
sudo dnf install --assumeyes --setopt=install_weak_deps=False @virtualization ${dependencies}
```

{% include upstream-vagrant-install.html distro="fedora" -%}
  Subsequently install remaining dependencies:

  ```shell
  sudo dnf install --assumeyes libvirt libguestfs-tools \
      gcc libvirt-devel libxml2-devel make ruby-devel
  ```

  Before installing the plugin it is necessary to compile some libraries to replace those
  shipped with the upstream vagrant to prevent the following errors from appearing when
  vagrant attempts to use vagrant-libvirt on recent Fedora releases.

{% include patch-vagrant-install.html distro="fedora" %}

  Finally install the plugin:
  ```
  vagrant plugin install vagrant-libvirt
  ```

#### Fedora 22 to 31

This has been kept for historical reasons given closeness to CentOS 6 & 7, however as Fedora no
longer supports these, they can be considered unsupported as well.

{% include upstream-vagrant-install.html distro="fedora" -%}
And subsequently install remaining dependencies and plugin:
```shell
sudo dnf install --assumeyes libvirt libguestfs-tools \
    gcc libvirt-devel libxml2-devel make ruby-devel
vagrant plugin install vagrant-libvirt
```

### CentOS

#### CentOS 8

{% include upstream-vagrant-install.html distro="centos" -%}
  Subsequently install remaining dependencies:

  ```shell
  sudo dnf install --assumeyes libvirt libguestfs-tools \
      gcc libvirt-devel libxml2-devel make ruby-devel
  ```

  Before installing the plugin it is necessary to compile some libraries to replace those
  shipped with the upstream vagrant to prevent the following errors from appearing when
  vagrant attempts to use vagrant-libvirt on recent CentOS releases.

{% include patch-vagrant-install.html distro="fedora" %}

  Finally install the plugin:
  ```
  vagrant plugin install vagrant-libvirt
  ```

#### CentOS 6 & 7

{% include upstream-vagrant-install.html distro="centos" -%}
And subsequently install remaining dependencies and plugin:
```shell
sudo yum install --assumeyes qemu qemu-kvm libvirt libguestfs-tools \
    gcc libvirt-devel make ruby-devel
vagrant plugin install vagrant-libvirt
```

### OpenSUSE

As there is no official upstream repository for OpenSUSE, it is recommended that you stick with the
distribution installation. OpenSUSE Leap appears to make the most recent vagrant available as an
experimental package based on [https://software.opensuse.org/package/vagrant](https://software.opensuse.org/package/vagrant).

#### Leap 15

* Distro Vagrant
```shell
sudo zypper refresh
sudo zypper addlock vagrant-libvirt
fog_libvirt_pkg="$(
    sudo zypper --terse -n --quiet search --provides "rubygem(fog-libvirt)" | \
    tail -n1 | cut -d' ' -f4)"
sudo zypper install --no-confirm libvirt qemu-kvm libguestfs vagrant ${fog_libvirt_pkg}
vagrant plugin install vagrant-libvirt
```

{% include upstream-vagrant-install.html distro="opensuse" -%}
  Subsequently install remaining dependencies:

  ```shell
  sudo zypper install --no-confirm libvirt qemu-kvm libguestfs \
      gcc make libvirt-devel ruby-devel
  ```

  Before installing the plugin it is necessary to compile some libraries to replace those
  shipped with the upstream vagrant to prevent the following errors from appearing when
  vagrant attempts to use vagrant-libvirt on recent OpenSUSE Leap releases.

{% include patch-vagrant-install.html distro="fedora" %}

  Finally install the plugin:
  ```
  vagrant plugin install vagrant-libvirt
  ```

### Arch

Please read the related [ArchWiki](https://wiki.archlinux.org/index.php/Vagrant#vagrant-libvirt) page.

As Arch is a rolling release, the version of vagrant available from the distribution should always be the most recent.
Unfortunately it does not appear to be possible to install ruby-libvirt from AUR anymore, which would remove
the need for the additional build tools.
```shell
sudo pacman --sync --sysupgrade --refresh
sudo pacman --query --search 'iptables' | grep "local" | grep "iptables " && \
    sudo pacman --remove --nodeps --nodeps --noconfirm iptables
sudo pacman --sync --needed --noprogressbar --noconfirm \
    iptables-nft libvirt qemu openbsd-netcat bridge-utils dnsmasq vagrant \
        pkg-config gcc make ruby
vagrant plugin install vagrant-libvirt
```

## Issues and Known Solutions

### Failure to find Libvirt for Native Extensions

Ensuring `pkg-config` or `pkgconf` is installed should be sufficient in most cases.

In some cases, you will need to specify `CONFIGURE_ARGS` variable before running running `vagrant plugin install`, e.g.:
```shell
export CONFIGURE_ARGS="with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib64"
vagrant plugin install vagrant-libvirt
```

If you have issues building ruby-libvirt, try the following (replace `lib` with `lib64` as needed):
```shell
CONFIGURE_ARGS='with-ldflags=-L/opt/vagrant/embedded/lib with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib' \
    GEM_HOME=~/.vagrant.d/gems \
    GEM_PATH=$GEM_HOME:/opt/vagrant/embedded/gems \
    PATH=/opt/vagrant/embedded/bin:$PATH \
        vagrant plugin install vagrant-libvirt
```

### Failure to Link

If have problem with installation - check your linker. It should be `ld.gold`:

```shell
sudo alternatives --set ld /usr/bin/ld.gold
# OR
sudo ln -fs /usr/bin/ld.gold /usr/bin/ld
```

### LoadError Exceptions

If you encounter the following load error when using the vagrant-libvirt plugin (note the required by libssh):

```/opt/vagrant/embedded/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:55:in `require': /opt/vagrant/embedded/lib64/libcrypto.so.1.1: version `OPENSSL_1_1_1b' not found (required by /lib64/libssh.so.4) - /home/xxx/.vagrant.d/gems/2.4.6/gems/ruby-libvirt-0.7.1/lib/_libvirt.so (LoadError)```

then the following steps have been found to resolve the problem. Thanks to James Reynolds (see https://github.com/hashicorp/vagrant/issues/11020#issuecomment-540043472). The specific version of libssh will change over time so references to the rpm in the commands below will need to be adjusted accordingly.

{: .info }
See distro specific instructions for variations on this that contain version independent steps.

```shell
# Fedora
dnf download --source libssh

# centos 8 stream, doesn't provide source RPMs, so you need to download like so
git clone https://git.centos.org/centos-git-common
# centos-git-common needs its tools in PATH
export PATH=$(readlink -f ./centos-git-common):$PATH
git clone https://git.centos.org/rpms/libssh
cd libssh
git checkout imports/c8s/libssh-0.9.4-1.el8
into_srpm.sh -d c8s
cd SRPMS

# common commands (make sure to adjust verison accordingly)
rpm2cpio libssh-0.9.4-1c8s.src.rpm | cpio -imdV
tar xf libssh-0.9.4.tar.xz
mkdir build
cmake ../libssh-0.9.4 -DOPENSSL_ROOT_DIR=/opt/vagrant/embedded/
make
sudo cp lib/libssh* /opt/vagrant/embedded/lib64
```

If you encounter the following load error when using the vagrant-libvirt plugin (note the required by libk5crypto):

```/opt/vagrant/embedded/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:55:in `require': /usr/lib64/libk5crypto.so.3: undefined symbol: EVP_KDF_ctrl, version OPENSSL_1_1_1b - /home/rbelgrave/.vagrant.d/gems/2.4.9/gems/ruby-libvirt-0.7.1/lib/_libvirt.so (LoadError)```

then the following steps have been found to resolve the problem. After the steps below are complete, then reinstall the vagrant-libvirt plugin without setting the `CONFIGURE_ARGS`. Thanks to Marco Bevc (see https://github.com/hashicorp/vagrant/issues/11020#issuecomment-625801983):

```shell
# Fedora
dnf download --source krb5-libs

# centos 8 stream, doesn't provide source RPMs, so you need to download like so
git clone https://git.centos.org/centos-git-common
# make get_sources.sh executable as it is needed in krb5
chmod +x centos-git-common/get_sources.sh
# centos-git-common needs its tools in PATH
export PATH=$(readlink -f ./centos-git-common):$PATH
git clone https://git.centos.org/rpms/krb5
cd krb5
git checkout imports/c8s/krb5-1.18.2-8.el8
get_sources.sh
into_srpm.sh -d c8s
cd SRPMS

# common commands (make sure to adjust verison accordingly)
rpm2cpio krb5-1.18.2-8c8s.src.rpm | cpio -imdV
tar xf krb5-1.18.2.tar.gz
cd krb5-1.18.2/src
./configure
make
sudo cp -P lib/crypto/libk5crypto.* /opt/vagrant/embedded/lib64/
```
