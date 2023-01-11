#!/bin/bash

# script with late commands, executed in target after install OS

## ---- Script header begin (Do not touch header!)

# save stdout and stderr to file
# descriptors 3 and 4,
# then redirect them to log file
exec 3>&1 4>&2 >/var/log/xubuntu-remaster.log 2>&1

set -Eeuo pipefail

ISO_VENDOR_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# shellcheck source=/dev/null
source "${ISO_VENDOR_DIR}/xubuntu-remaster.conf"
cp "${ISO_VENDOR_DIR}/xubuntu-remaster.conf" /etc/

function log() {
	echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}
ifIsSet() {
	[[ ${!1-x} == x ]] && return 1 || return 0
}

log "Create service to be started on boot"
if ifIsSet FIRST_BOOT_SCRIPT; then
	cp "${ISO_VENDOR_DIR}/xubuntu-remaster-first-boot" /usr/bin/xubuntu-remaster-first-boot
	chmod 755 /usr/bin/xubuntu-remaster-first-boot

	cat >/lib/systemd/system/xubuntu-remaster-first-boot.service <<EOF
[Install]
WantedBy=multi-user.target

[Unit]
Description=XUbuntu remaster first boot service
After=network.target

[Service]
User=root
Group=root
Nice=0
ExecStart=/usr/bin/xubuntu-remaster-first-boot
Restart=no
EOF

	systemctl -q unmask xubuntu-remaster-first-boot.service
	systemctl -q enable xubuntu-remaster-first-boot.service
fi

if [ -f "${ISO_VENDOR_DIR}/logo.png" ]; then
	log "Copy logo"
	cp "${ISO_VENDOR_DIR}/logo.png" /usr/share/plymouth/ubuntu-logo.png
fi

log "Change plymouth theme"
cat >/usr/share/plymouth/themes/ubuntu-text/ubuntu-text.plymouth <<XXX
[Plymouth Theme]
Name=Ubuntu Text
Description=Text mode theme based on ubuntu-logo theme
ModuleName=ubuntu-text

[ubuntu-text]
title=(c) $(date +"%Y") ${VENDOR_NAME}
black=0x2c001e
white=0xffffff
brown=0xff4012
blue=0x988592

XXX

## ---- Script header end (Do not touch header!)

# example customization

log "Create home directory /home/${LOCAL_USER}"
# NOTE: user from identity and user-data was created after reboot!
mkdir -p "/home/${LOCAL_USER}"

# user number
USERN=1000

if [ -d "${ISO_VENDOR_DIR}/.ssh" ]; then
	log "Install remote certs in /root/.ssh and /home/${LOCAL_USER}/.ssh"
	cp -a "${ISO_VENDOR_DIR}/.ssh" /root/
	chmod 700 /root/.ssh
	[[ -f /root/.ssh/authorized_keys ]] && chmod 600 /root/.ssh/authorized_keys

	cp -a "${ISO_VENDOR_DIR}/.ssh" "/home/${LOCAL_USER}/"
	chmod 700 "/home/${LOCAL_USER}/.ssh"
	[[ -f "/home/${LOCAL_USER}/.ssh/authorized_keys" ]] && chmod 600 "/home/${LOCAL_USER}/.ssh/authorized_keys"
fi

log "Set bash aliases for root"
echo source /root/.bash_aliases >/root/.profile
echo alias dir=\'ls -laF --color=auto\' >/root/.bash_aliases

log "Set bash aliases for local user"
echo "source \"/home/${LOCAL_USER}/.bash_aliases\"" >"/home/${LOCAL_USER}/.profile"
echo alias dir=\'ls -laF --color=auto\' >"/home/${LOCAL_USER}/.bash_aliases"

chown ${USERN}.${USERN} "/home/${LOCAL_USER}" -R

log "Disable ssh password login"
mkdir -p /etc/ssh/sshd_config.d/
cat >/etc/ssh/sshd_config.d/xubuntu-remaster.conf <<XXX
PermitRootLogin yes
PasswordAuthentication no

XXX

log "Generate unseal script with initial password"
cat >/usr/lib/xubuntu-remaster-unseal <<EOF
#!/bin/sh

#CRYPTTAB_NAME=mmcblk0p3_crypt
#CRYPTTAB_SOURCE=/dev/mmcblk0p3

TMP_FILE=".tpm2-getkey.\${CRYPTTAB_NAME}.tmp"
if [ -f "\${TMP_FILE}" ]; then
	# tmp file exists, meaning we tried the TPM this boot, but it didn’t work for the drive and this must be the second
	# or later pass for the drive. Either the TPM is failed/missing, or has the wrong key stored in it.
	/lib/cryptsetup/askpass "Automatic disk unlock via TPM failed for (\$CRYPTTAB_SOURCE) Enter passphrase: "
	exit
fi
# No tmp, so it is the first time trying the script. Create a tmp file and try the TPM
touch \${TMP_FILE}

printf "%s" "${INITIAL_LUKS_PASS}"
EOF

chmod 755 /usr/lib/xubuntu-remaster-unseal

log "Generate script to add unseal script to initramfs"
cat >/etc/initramfs-tools/hooks/xubuntu-remaster-initramfs-tool <<EOF
. /usr/share/initramfs-tools/hook-functions

copy_exec /usr/lib/xubuntu-remaster-unseal
EOF

chmod 755 /etc/initramfs-tools/hooks/xubuntu-remaster-initramfs-tool

log "Change /etc/crypttab"
if [ -f /etc/crypttab ]; then
	sed -i 's/luks/luks,discard,keyscript=\/usr\/lib\/xubuntu-remaster-unseal/g' /etc/crypttab
fi

log "Update initramfs"
update-initramfs -u

## ---- Script footer begin (Do not touch footer!)

log "Clean"
apt --purge -y autoremove
apt -qq clean
rm -rf /var/lib/apt/lists/*

sync

log "Done"

# restore stdout and stderr
exec 1>&3 2>&4

chmod 0400 /var/log/xubuntu-remaster.log

exit 0
## ---- Script footer end (Do not touch footer!)
