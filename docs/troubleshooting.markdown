---
title: Troubleshooting
nav_order: 7
toc: true
---

The first step for troubleshooting a VM image that appears to not boot correctly,
or hangs waiting to get an IP, is to check it with a VNC viewer. A key thing
to remember is that if the VM doesn't get an IP, then vagrant can't communicate
with it to configure anything, so a problem at this stage is likely to come from
the VM, but we'll outline the tools and common problems to help you troubleshoot
that.

By default, when you create a new VM, a vnc server will listen on `127.0.0.1` on
port `TCP5900`. If you connect with a vnc viewer you can see the boot process. If
your VM isn't listening on `5900` by default;

 * Check the create domain details outputted to the console, or
 * Use `virsh dumpxml` to find out which port it's listening on, or
 * Explicitly configure it with `graphics_port` and `graphics_ip`
   (see ['Domain Specific Options']({{ '/configuration#domain-specific-options' | relative_url }})).

Note: Connecting with the console (`virsh console`) requires additional config,
so some VMs may not show anything on the console at all, instead displaying it in
the VNC console. The issue with the text console is that you also need to build the
image used to tell the kernel to output to the console during boot, and typically
most do not have this built in.

Problems we've seen in the past include:
- Forgetting to remove `/etc/udev/rules.d/70-persistent-net.rules` before packaging
the VM
- VMs expecting a specific disk device to be connected

If you're still confused, check the Github Issues for this repo for anything that
looks similar to your problem.

[Github Issue #1032](https://github.com/vagrant-libvirt/vagrant-libvirt/issues/1032)
contains some historical troubleshooting for VMs that appeared to hang.

Did you hit a problem that you'd like to note here to save time in the future?
Please do!
