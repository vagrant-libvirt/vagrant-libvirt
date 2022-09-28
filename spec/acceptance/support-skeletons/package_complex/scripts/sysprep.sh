#!/bin/sh -eux

# consider purging any packages you don't need here

echo "autoremoving packages and cleaning apt data"
apt-get -y autoremove;
apt-get -y clean;

# repeat what machine-ids does in sysprep as this script needs to run via customize
# which has a bug resulting in the machine-ids being regenerated

if [ -f /etc/machine-id ]
then
    truncate --size=0 /etc/machine-id
fi

if [ -f /var/lib/dbus/machine-id ]
then
    truncate --size=0 /run/machine-id
fi

echo "remove /var/cache"
find /var/cache -type f -exec rm -rf {} \;

echo "force a new random seed to be generated"
rm -f /var/lib/systemd/random-seed

# for debian based systems ensure host keys regenerated on boot
if [ -e /usr/sbin/dpkg-reconfigure ]
then
    printf "@reboot root command bash -c 'export PATH=$PATH:/usr/sbin ; export DEBIAN_FRONTEND=noninteractive ; export DEBCONF_NONINTERACTIVE_SEEN=true ; /usr/sbin/dpkg-reconfigure openssh-server &>/dev/null ; /bin/systemctl restart ssh.service ; rm --force /etc/cron.d/keys'\n" > /etc/cron.d/keys
fi
