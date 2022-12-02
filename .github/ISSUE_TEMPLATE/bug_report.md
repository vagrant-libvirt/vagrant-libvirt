---
name: Bug report
about: Create a report to help us improve
title: ''
labels: ''
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

<!--
To test if the issue exists in the latest code you can download a pre-built gem of what is on main from the GitHub
rubygems package [repository](https://github.com/vagrant-libvirt/vagrant-libvirt/packages/1659776) under the
asserts. Unfortunately it's not yet possible to make the rubygem repositories in GitHub public.

To install provide the file directly to the install command:
```
vagrant plugin install ./vagrant-libvirt-<version>.gem
```

It is possible to install directly from the GitHub rubygems package repository, however this will embedded
your GitHub token directly into the file `~/.vagrant.d/plugins.json`:
```
vagrant plugin install vagrant-libvirt \
  --plugin-source https://${USERNAME}:${GITHUB_TOKEN}@rubygems.pkg.github.com/vagrant-libvirt \
  --plugin-version "0.10.9.pre.62"
```

Provided this token is a classic token limited to `read:packages` only, this may be acceptable to you.
-->

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Versions (please complete the following information):**:
- Libvirt version:
- Vagrant version [output of `vagrant version`]:
- Vagrant flavour [Upstream or Distro]: 
- Vagrant plugins versions (including vagrant-libvirt) [output of `vagrant plugin list`]:

**Debug Log**
Attach Output of `VAGRANT_LOG=debug vagrant ... --provider=libvirt >vagrant.log 2>&1`
```
Delete this text and drag and drop the log file for github to attach and add a link here
```

**A Vagrantfile to reproduce the issue:**
```
Insert Vagrantfile inside quotes here (remove sensitive data if needed)
```
