# Vagrant Libvirt Example Box

Vagrant providers each require a custom provider-specific box format.
This folder shows the example contents of a box for the `libvirt` provider.
To turn this into a box create a vagrant image according documentation (don't
forget to install rsync command) and create box with following command:

```
$ tar cvzf custom_box.box ./metadata.json ./Vagrantfile ./box.img
```

This box works by using Vagrant's built-in Vagrantfile merging to setup
defaults for Libvirt. These defaults can easily be overwritten by higher-level
Vagrantfiles (such as project root Vagrantfiles).

## Box Metadata

Libvirt box should define at least three data fields in `metadata.json` file.

* provider - Provider name is libvirt.
* format - Currently supported format is qcow2.
* virtual_size - Virtual size of image in GBytes.

## Converting Boxes

Instead of creating a box from scratch, you can use 
[vagrant-mutate](https://github.com/sciurus/vagrant-mutate) 
to take boxes created for other Vagrant providers and use them 
with vagrant-libvirt.
