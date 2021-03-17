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
        # be able to determine suitable uid/gid
        ;;
    *)
        echo "${vdir} is not set to a bind mounted volume, will not be able"
        echo "to automatically determine suitable uid/gid to execute under."
        if [[ -z "${USER_UID:-}" ]] || [[ -z "${USER_GID:-}" ]]
        then
            echo "USER_UID and USER_GID must be explicitly provided when"
            echo "auto-detection is unable to be used"

            exit 2
        fi
        ;;
esac

USER_UID=${USER_UID:-$(stat -c %u ${vdir})} || exit 3
USER_GID=${USER_GID:-$(stat -c %g ${vdir})} || exit 3
if [[ ${USER_UID} -eq 0 ]] && [[ -z "${IGNORE_RUN_AS_ROOT:-}" ]]
then
    echo "WARNING! Running as root, if this breaks, you get to keep both pieces"
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
