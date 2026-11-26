# frozen_string_literal: true

require 'fileutils'

require_relative '../spec_helper'

describe '9p synced folder', acceptance: true do
  include_context 'libvirt_acceptance'

  # where the share is mounted in the guest, see the skeleton
  let(:guest_path) { '/vagrant_shared' }

  # the host side of that share
  let(:shared_dir) { environment.workdir.join('shared') }

  # the line Vagrant renders into /etc/fstab for the share, laid out by
  # templates/guests/linux/etc_fstab.erb of Vagrant itself:
  #
  #   <mount tag> <mount point> <type> <options> <dump> <fsck>
  let(:fstab_entry) do
    %r{^\s*(?<tag>\S+)\s+#{Regexp.escape(guest_path)}\s+9p\s+(?<options>\S+)\s+\d+\s+\d+\s*$}
  end

  before do
    environment.skeleton('9p')

    # 9p passthrough performs the file operations as the user the qemu process
    # runs as, which is an unprivileged one on most distributions, so open up
    # the temporary environment for it
    shared_dir.mkpath
    FileUtils.chmod(0o755, environment.workdir.dirname)
    FileUtils.chmod(0o755, environment.workdir)
    FileUtils.chmod(0o777, shared_dir)
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should still be mounted for a provisioner running after a reboot' do
    status('Test: create and provision the machine')
    # the second provisioner runs after the first one rebooted the guest and
    # checks the mount itself, so a share that did not come back fails here
    expect(environment.execute('vagrant', 'up')).to exit_with(0)

    status('Test: check the provisioner before the reboot wrote through to the host')
    expect(shared_dir.join('before.output')).to have_file_content(/\S/)

    status('Test: check the provisioner after the reboot wrote through to the host')
    # an unmounted share leaves the guest writing into the bare mount point,
    # where the file never reaches the host
    expect(shared_dir.join('after.output')).to have_file_content(/\S/)

    status('Test: check the mount is persisted in /etc/fstab')
    managed = vagrant_managed_fstab
    entry = fstab_entry.match(managed)
    expect(entry).not_to be_nil,
                         "no 9p entry for #{guest_path} in the Vagrant managed fstab block:\n#{managed}"

    status('Test: check it is mounted over the virtio transport')
    expect(entry[:options].split(',')).to include('trans=virtio')

    status('Test: check a share that is gone cannot block the boot of the guest')
    expect(entry[:options].split(',')).to include('nofail')
  end

  # @return [String] the part of the guest /etc/fstab that Vagrant manages
  def vagrant_managed_fstab
    fstab = assert_execute('vagrant', 'ssh', '-c', 'cat /etc/fstab').stdout
    managed = fstab[/#VAGRANT-BEGIN$(.*)^#VAGRANT-END/m, 1]
    expect(managed).not_to be_nil, "/etc/fstab has no Vagrant managed block:\n#{fstab}"

    managed
  end
end
