#!/bin/bash

# Script to manipulate squashfs filesystem
# Executed before creating new iso

## ---- Script header begin (Do not touch header!)
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

function log() {
	echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}
ifIsSet() {
	[[ ${!1-x} == x ]] && return 1 || return 0
}
ifNotSet() {
	[[ ${!1-x} == x ]] && return 0 || return 1
}

# disable progress bar
APT_OPTIONS="-o Dpkg::Progress-Fancy='0' "

# check for apt proxy
if [ -f /extra_files/apt_proxy.sh ]; then

	# shellcheck source=/dev/null
	source "/extra_files/apt_proxy.sh"

	if ifIsSet APT_PROXY; then
		# NOTEL curl is not installed!
		# APT_PROXY_CHECH=$(curl --connect-timeout 2 --max-time 5 -s "${APT_PROXY}" -o /dev/null -w "%{http_code}" || true)
		APT_PROXY_CHECH=$(wget --connect-timeout=2 --timeout=3 --tries=1 -S -q --max-redirect=0 "${APT_PROXY}" 2>&1 | awk 'NR==1{print $2}' || true)
		if [ "${APT_PROXY_CHECH}" -ne 406 ]; then
			log "apt proxy ${APT_PROXY} not detected!"
		else
			APT_OPTIONS="${APT_OPTIONS} -o Acquire::http::Proxy='${APT_PROXY}'"
			log "Set apt proxy to ${APT_PROXY}"
		fi
	fi
fi

function xapt() {
	eval "apt ${APT_OPTIONS} $*"
}

log "apt update"
xapt -qq update

# log "apt upgrade"
# apt -y upgrade Do not upgrade!
## ---- Script header end (Do not touch header!)

## ---- User part of script begin

log "install extra packages"
xapt -qq install -y \
	vim \
	htop \
	net-tools \
	tpm2-tools \
	tpm2-initramfs-tool

log "download and install latest version of security packages"
# NOTE: last step!
github_latest_deb() {
	curl -s "https://api.github.com/repos/${1}/releases/latest" | grep "browser_download_url.*deb" | cut -d ':' -f 2,3 | tr -d \" | xargs
}
curl -fsSL "$(github_latest_deb ivan-danov/xgrub-password)" -o /xgrub-password.deb
curl -fsSL "$(github_latest_deb ivan-danov/xtpm2-password)" -o /xtpm2-password.deb
xapt -qq install -y /xgrub-password.deb /xtpm2-password.deb
rm /xgrub-password.deb
rm /xtpm2-password.deb

## ---- User part of script end

## ---- Script footer begin (Do not touch footer!)

log "clean"
xapt -qq clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* ~/.bash_history

log "generate filesystem.manifest file"
dpkg-query --show --showformat='${binary:Package}\t${Version}\n' >/filesystem.manifest

log "done"
exit 0
# ---- Script footer end (Do not touch footer!)
