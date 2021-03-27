
VAGRANT_HOME=${1:-$HOME/.vagrant.d/}
VAGRANT_CMD=${2:-vagrant}

echo 'Create box with two disks'
${VAGRANT_CMD} box list
${VAGRANT_CMD} box list --machine-readable
if [ "$(${VAGRANT_CMD} box list | grep -c -E '^infernix/tinycore-two-disks\s')" -eq 0 ]
then
    if [ "$(${VAGRANT_CMD} box list | grep -c -E '^infernix/tinycore\s')" -eq 0 ]
    then
        ${VAGRANT_CMD} box add infernix/tinycore
    fi
    ls "${VAGRANT_HOME}/"
    ls "${VAGRANT_HOME}/boxes/"
    NEW_PATH="${VAGRANT_HOME}/boxes/infernix-VAGRANTSLASH-tinycore-two-disks"
    cp -r "${VAGRANT_HOME}/boxes/infernix-VAGRANTSLASH-tinycore" "${NEW_PATH}"
    BOX_VERSION="$(${VAGRANT_CMD} box list --machine-readable | grep -A 10 infernix/tinycore-two-disks | grep box-version | cut -d, -f4)"
    qemu-img create -f qcow2 "${NEW_PATH}/${BOX_VERSION}/libvirt/disk2.qcow2" 10G
    cat > "${NEW_PATH}/${BOX_VERSION}/libvirt/metadata.json" <<EOF
{
  "provider": "libvirt",
  "format": "qcow2",
  "disks" : [
      {
          "virtual_size": 2
      },
      {
          "path":"disk2.qcow2",
          "virtual_size":10
      }
  ]
}
EOF
fi
