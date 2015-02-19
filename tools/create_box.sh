#!/usr/bin/env bash

error() {
    local msg="${1}"
    echo "==> ${msg}"
    exit 1
}

usage() {
    echo "Usage: ${0} IMAGE [BOX]"
    echo
    echo "Package a qcow2 image into a vagrant-libvirt reusable box"
}

# Print the image's backing file
backing(){
    local img=${1}
    qemu-img info $img | grep 'backing file:' | cut -d ':' -f2
}

# Rebase the image
rebase(){
    local img=${1}
    qemu-img rebase -p -b "" $img
    [[ "$?" -ne 0 ]] && error "Error during rebase"
}

# Is absolute path
isabspath(){
    local path=${1}
    [[ $path =~ ^/.* ]]
}

if [ -z "$1" ]; then
    usage
    exit 1
fi

IMG=$(readlink -e $1)
[[ "$?" -ne 0 ]] && error "'$2': No such image"

IMG_DIR=$(dirname $IMG)
IMG_BASENAME=$(basename $IMG)

# If no box name is supplied infer one from image name
if [[ -z "$2" ]]; then
    BOX_NAME=${IMG_BASENAME%.*}
    BOX=$BOX_NAME.box
else
    BOX="$2"
    BOX_NAME=$(basename ${BOX%.*})
fi

[[ -f "$BOX" ]] && error "'$BOX': Already exists"

CWD=$(pwd)
TMP_DIR=$CWD/_tmp_package
TMP_IMG=$TMP_DIR/box.img

mkdir -p $TMP_DIR

# We move / copy (when the image has master) the image to the tempdir
# ensure that it's moved back / removed again
if [[ -n $(backing $IMG) ]]; then
    echo "==> Image has backing image, copying image and rebasing ..."
    trap "rm -rf $TMP_DIR" EXIT
    cp $IMG $TMP_IMG
    rebase $TMP_IMG
else
    trap "mv $TMP_IMG $IMG; rm -rf $TMP_DIR" EXIT
    mv $IMG $TMP_IMG
fi

cd $TMP_DIR

IMG_SIZE=$(qemu-img info $TMP_IMG | grep 'virtual size' | awk '{print $3;}' | tr -d 'G')

cat > metadata.json <<EOF
{
    "provider": "libvirt",
    "format": "qcow2",
    "virtual_size": ${IMG_SIZE}
}
EOF

cat > Vagrantfile <<EOF
Vagrant.configure("2") do |config|

  config.vm.provider :libvirt do |libvirt|

    libvirt.driver = "kvm"
    libvirt.host = ""
    libvirt.connect_via_ssh = false
    libvirt.storage_pool_name = "default"

  end
end
EOF

echo "==> Creating box, tarring and gzipping"

tar cvzf $BOX --totals ./metadata.json ./Vagrantfile ./box.img

# if box is in tmpdir move it to CWD before removing tmpdir
if ! isabspath $BOX; then
    mv $BOX $CWD
fi

echo "==> ${BOX} created"
echo "==> You can now add the box:"
echo "==>   'vagrant box add ${BOX} --name ${BOX_NAME}'"
