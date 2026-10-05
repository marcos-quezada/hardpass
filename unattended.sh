#!/bin/sh

# Adapted from macmpi's alpine-linux-headless-bootstrap contribs/unattended_sysdisk.sh
# (MIT licensed), customized for the hardpass-pi-reproducible-setup project.

MY_USER="hardpass"
MY_PASS="REPLACE_ME_choose_a_real_password"
MY_IFACE="wlan0"
MY_HOSTNAME="hardpass"
MY_DISK="mmcblk0"
MY_BOOT="${MY_DISK}p1"
MY_ROOT="${MY_DISK}p2"
MY_ROOT_SIZE="$((55*1024))"

alias _logger='logger -st "${0##*/}"'

ovl="$( dmesg | grep -o 'Loading user settings from .*:' | awk '{print $5}' | sed 's/:.*$//' )"
if [ -f "${ovl}" ]; then
	ovlpath="$( dirname "$ovl" )"
else
	ovl="$( basename "${ovl}" )"
	ovlpath=$( find /media -maxdepth 2 -type d -path '*/.*' -prune -o -type f -name "${ovl}" -exec dirname {} \; | head -1 )
	ovl="${ovlpath}/${ovl}"
fi

MY_TMP="$( mktemp -d )"
cp -a "${ovlpath}"/interfaces "$MY_TMP"/interfaces >/dev/null 2>&1
cp -a "${ovlpath}"/wpa_supplicant.conf "$MY_TMP"/wpa_supplicant.conf >/dev/null 2>&1
cp -a  /root/.ssh/authorized_keys "$MY_TMP"/authorized_keys >/dev/null 2>&1 || cp -a "${ovlpath}"/authorized_keys "$MY_TMP"/authorized_keys >/dev/null 2>&1

_logger "Starting base sys-disk installation"
cat <<-EOF > /tmp/ANSWERFILE
	KEYMAPOPTS=none
	HOSTNAMEOPTS="$MY_HOSTNAME"
	DEVDOPTS=mdev
	INTERFACESOPTS="auto lo
	iface lo inet loopback

	auto $MY_IFACE
	iface $MY_IFACE inet dhcp

	auto usb0
	iface usb0 inet static
	    address 10.18.1.19
	    netmask 255.255.255.0
	"
	DNSOPTS=""
	TIMEZONEOPTS=CET
	PROXYOPTS=none
	APKREPOSOPTS="http://dl-cdn.alpinelinux.org/alpine/v3.22/main http://dl-cdn.alpinelinux.org/alpine/v3.22/community"
	USEROPTS="-a -u $MY_USER"
	SSHDOPTS=openssh
	NTPOPTS=chrony

	export ERASE_DISKS=/dev/$MY_DISK
	export ROOT_SIZE=$MY_ROOT_SIZE
	DISKOPTS="-m sys /dev/$MY_DISK"
	EOF

SSH_CONNECTION="FAKE" setup-alpine -ef /tmp/ANSWERFILE

_logger "Prepare sys-setup script"
cat <<-EOF >/tmp/sys-setup.sh
	#!/bin/sh

	alias _logger='logger -st "${0##*/}"'

	if install -m644 "$MY_TMP"/interfaces /etc/network/interfaces >/dev/null 2>&1; then
		_logger "Imported interfaces file"
	fi

	if [ -e "$MY_TMP"/wpa_supplicant.conf ]; then
		apk add wpa_supplicant
		install -m644 "$MY_TMP"/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
		rc-update add wpa_supplicant boot
		_logger "Wifi configured with imported wpa_supplicant.conf"
	fi

	if install -Dm600 "$MY_TMP"/authorized_keys /home/"$MY_USER"/.ssh/authorized_keys >/dev/null 2>&1; then
			_logger "Imported public key SSH for authentication."
			chown -R "$MY_USER" /home/"$MY_USER"/.ssh
	fi
	mkdir -p /root/.ssh
	cp "$MY_TMP"/authorized_keys /root/.ssh/authorized_keys 2>/dev/null
	chmod 600 /root/.ssh/authorized_keys 2>/dev/null

	rm -rf "$MY_TMP"

	echo "$MY_USER:$MY_PASS" | chpasswd
	echo "root:$MY_PASS" | chpasswd

	apk update
	apk upgrade --available
	apk add xg_multi doas

	echo "permit persist :wheel" > /etc/doas.d/doas.conf
	adduser "$MY_USER" wheel 2>/dev/null

	EOF
chmod +x /tmp/sys-setup.sh

_logger "Mounting new system for post-installation"
mkdir -p /mnt/boot /mnt/tmp /mnt/dev /mnt/proc /mnt/sys
mount /dev/$MY_ROOT /mnt
mount /dev/$MY_BOOT /mnt/boot
mount --bind /tmp /mnt/tmp
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

_logger "Running sys-setup script on disk-based system"
chroot /mnt /tmp/sys-setup.sh
sync

_logger "Cleaning up mounts"
umount /mnt/sys
umount /mnt/proc
umount /mnt/dev
umount /mnt/tmp
umount /mnt/boot
umount /mnt

_logger "Finished unattended script - rebooting system"
reboot
