#!/bin/bash

# script to execute on first boot in new OS as root

# save stdout and stderr to file
# descriptors 3 and 4,
# then redirect them to log file
exec 3>&1 4>&2 >/var/log/xubuntu-remaster-first-boot.log 2>&1

set -Eeuo pipefail

# SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"

function log() {
        echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

CONFIG_FILE=/etc/xubuntu-remaster.conf
if [ -f ${CONFIG_FILE} ]; then
	# shellcheck source=/dev/null
	source ${CONFIG_FILE}
else
	log "No config file ${CONFIG_FILE}"
fi

log "Set (or download from server) password params"
GRUB2_USER=grubadmin
GRUB2_PASS=grubpassword
TPM2_LUKS_PASS=lukspassword

log "Set password for Grub2 MenuItem edit"
echo ${GRUB2_PASS}|xgrub-password ${GRUB2_USER}

log "Check for tpm2"
if [ -c /dev/tpmrm0 ]; then
	log "TPM 2.0 found" # since v4.12-rc1

	log "Remove unseal script with initial password"
	if [ -f /etc/crypttab ]; then
		log "Restore crypttab"
		sed -i 's/luks,discard,keyscript=\/usr\/lib\/xubuntu-remaster-unseal/luks/g' /etc/crypttab
	fi
	rm -f /usr/lib/xubuntu-remaster-unseal
	rm -f /etc/initramfs-tools/hooks/xubuntu-remaster-initramfs-tool

	log "Change unlock password of encrypted disk with tpm2 chip"
	xtpm2-password "${INITIAL_LUKS_PASS}" "${TPM2_LUKS_PASS}"
else
	log "TPM 2.0 NOT found"
fi


# script footer begin (Do not touch footer!)

log "Disable service xubuntu-remaster-first-boot"
systemctl disable xubuntu-remaster-first-boot
systemctl mask xubuntu-remaster-first-boot

log "Done"

# restore stdout and stderr
exec 1>&3 2>&4

chmod 0400 /var/log/xubuntu-remaster-first-boot.log

exit 0
# script footer end (Do not touch footer!)
