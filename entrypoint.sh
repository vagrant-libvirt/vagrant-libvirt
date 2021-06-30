#!/bin/bash

set -u -o pipefail

vdir="/.vagrant.d"

if [[ ! -d ${vdir} ]]
then
    echo "Require the user ~/.vagrant.d to be bind mounted at ${vdir}"
    echo
    echo "Typically use '-v ~/.vagrant.d:${vdir}' with the docker run command."

    exit 2
fi

vdir_mnt=$(stat -c %m ${vdir})
case "${vdir_mnt%%/}" in
    /*)
        # user mounted vagrant home is not mounted on /, so
        # presumably it is a mount bind or mounted volume and should
        # be able to persist boxes and machine index.
        #
        ;;
    *)
        echo -n "${vdir} is not set to a bind mounted volume, may not be able "
        echo -n "to persist the machine index which may result in some unexpected "
        echo "behaviour."
        ;;
esac

# To determine default user to use search for the Vagrantfile starting with
# the current working directory. If it can't be found, use the owner/group
# from the current working directory anyway
vagrantfile="${VAGRANT_VAGRANTFILE:-Vagrantfile}"
path="$(pwd)"
while [[ "$path" != "" && ! -e "$path/$1" ]]
do
    path=${path%/*}
done

if [[ "$path" == "" ]]
then
    path="$(pwd)"
fi

USER_UID=${USER_UID:-$(stat -c %u ${path})} || exit 3
USER_GID=${USER_GID:-$(stat -c %g ${path})} || exit 3
if [[ ${USER_UID} -eq 0 ]]
then
    if [[ -z "${IGNORE_RUN_AS_ROOT:-}" ]]
    then
        echo "WARNING! Running as root, if this breaks, you get to keep both pieces"
    fi
else
    vdir_uid=$(stat -c %u ${vdir})
    if [[ "${vdir_uid}" != "${USER_UID}" ]]
    then
        if [[ -z "$(ls -A ${vdir})" ]]
        then
            # vdir has just been created and is owned by the wrong user
            # modify the ownership to allow the required directories to
            # be created
            chown ${USER_UID}:${USER_GID} ${vdir}
        else
            echo -n "ERROR: Attempting to use a directory on ${vdir} that is not "
            echo -n "owned by the user that owns ${path}/${vagrantfile} is not "
            echo "supported!"

            exit 2
        fi
    fi
fi

export USER=vagrant
export GROUP=users
export HOME=/home/${USER}

echo "Starting with UID: ${USER_UID}, GID: ${USER_GID}"
if [[ "${USER_GID}" != "0" ]]
then
    if getent group ${GROUP} > /dev/null
    then
        GROUPCMD=groupmod
    else
        GROUPCMD=groupadd
    fi
    ${GROUPCMD} -g ${USER_GID} ${GROUP} >/dev/null || exit 3
fi

if [[ "${USER_UID}" != "0" ]]
then
    if getent passwd ${USER} > /dev/null
    then
        USERCMD=usermod
    else
        USERCMD=useradd
    fi
    ${USERCMD} --shell /bin/bash -u ${USER_UID} -g ${USER_GID} -o -c "" -m ${USER} >/dev/null 2>&1 || exit 3
fi

# Perform switching in of boxes, data directory containing machine index
# and temporary directory from the user mounted environment
for dir in boxes data tmp
do
    # if the directory hasn't been explicitly mounted over, remove it.
    if [[ -e "/vagrant/${dir}/.remove" ]]
    then
        rm -rf /vagrant/${dir}
        [[ ! -e ${vdir}/${dir} ]] && gosu ${USER} mkdir ${vdir}/${dir}
        ln -s ${vdir}/${dir} /vagrant/${dir}
    fi
done

# make sure the directories can be written to by vagrant otherwise will
# get a start up error
find ${VAGRANT_HOME} -maxdepth 1 ! -exec chown -h ${USER}:${GROUP} {} \+

LIBVIRT_SOCK=/var/run/libvirt/libvirt-sock
if [[ ! -S ${LIBVIRT_SOCK} ]]
then
    if [[ -z "${IGNORE_MISSING_LIBVIRT_SOCK:-}" ]]
    then
        echo "Unless you are using this to connect to a remote libvirtd it is"
        echo "necessary to mount the libvirt socket in as ${LIBVIRT_SOCK}"
        echo
        echo "Set IGNORE_MISSING_LIBVIRT_SOCK to silence this warning"
    fi
else
    LIBVIRT_GID=$(stat -c %g ${LIBVIRT_SOCK})
    # only do this if the host uses a non-root group for libvirt
    if [[ ${LIBVIRT_GID} -ne 0 ]]
    then
        if getent group libvirt >/dev/null
        then
            GROUPCMD=groupmod
        else
            GROUPCMD=groupadd
        fi
        ${GROUPCMD} -g ${LIBVIRT_GID} libvirt >/dev/null || exit 3

        usermod -a -G libvirt ${USER} || exit 3
    fi
fi

if [[ $# -eq 0 ]]
then
    # if no command provided
    exec gosu ${USER} vagrant help
fi

exec gosu ${USER} "$@"
