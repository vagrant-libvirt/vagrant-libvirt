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

    # the qemu process serves the share, and it runs as an unprivileged user
    # on most distributions, so open up the temporary environment for it
    shared_dir.mkpath
    FileUtils.chmod(0o755, environment.workdir.dirname)
    FileUtils.chmod(0o755, environment.workdir)
    FileUtils.chmod(0o777, shared_dir)
  end

  after do
    assert_execute('vagrant', 'destroy', '--force')
  end

  it 'should be mounted and persisted in /etc/fstab' do
    status('Test: create and provision the machine')
    # the provisioner checks the mount itself, see the skeleton
    expect(environment.execute('vagrant', 'up')).to exit_with(0)

    status('Test: check the mount is persisted in /etc/fstab')
    managed = vagrant_managed_fstab
    entry = fstab_entry.match(managed)
    expect(entry).not_to be_nil,
                         "no 9p entry for #{guest_path} in the Vagrant managed fstab block:\n#{managed}"

    status('Test: check it is mounted over the virtio transport')
    expect(entry[:options].split(',')).to include('trans=virtio')

    status('Test: check a share that is gone cannot block the boot of the guest')
    expect(entry[:options].split(',')).to include('nofail')

    status('Test: check the persisted entry can mount the share')
    # the guest is not rebooted here, so mount the entry by hand. An entry
    # carrying an option the 9p client does not take would be written and
    # found above all the same, and only fail once something mounts it.
    remount = 'sudo umount %<path>s && sudo mount %<path>s && ' \
              'findmnt --type 9p --target %<path>s' % { path: guest_path }
    expect(execute_ssh('-c', remount)).to exit_with(0)
  end

  # @return [String] the part of the guest /etc/fstab that Vagrant manages
  def vagrant_managed_fstab
    fstab = assert_execute('vagrant', 'ssh', '-c', 'cat /etc/fstab').stdout
    managed = fstab[/#VAGRANT-BEGIN$(.*)^#VAGRANT-END/m, 1]
    expect(managed).not_to be_nil, "/etc/fstab has no Vagrant managed block:\n#{fstab}"

    managed
  end
end
