#!/bin/bash

# Script to manipulate squashfs filesystem
# Executed before creating new iso

## ---- Script header begin (Do not touch header!)
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "apt update"
apt-get -qq update

# echo "apt upgrade"
# apt -y upgrade Do not upgrade!
## ---- Script header end (Do not touch header!)


## ---- User part of script begin

echo "install extra packages"
apt-get -qq install -y \
	vim \
	htop \
	net-tools \
	tpm2-tools \
	tpm2-initramfs-tool

echo "download and install latest version of security packages"
# NOTE: last step!
github_latest_deb() {
        curl -s "https://api.github.com/repos/${1}/releases/latest"|grep "browser_download_url.*deb"|cut -d ':' -f 2,3|tr -d \"|xargs
}
curl -fsSL $(github_latest_deb ivan-danov/xgrub-password) -o /xgrub-password.deb
curl -fsSL $(github_latest_deb ivan-danov/xtpm2-password) -o /xtpm2-password.deb
apt-get -qq install -y /xgrub-password.deb /xtpm2-password.deb
rm /xgrub-password.deb
rm /xtpm2-password.deb

## ---- User part of script end


## ---- Script footer begin (Do not touch footer!)

### clean
apt-get -qq clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* ~/.bash_history

### generate filesystem.manifest file
dpkg-query -W --showformat='${Package} ${Version}\n' > /filesystem.manifest

exit
# ---- Script footer end (Do not touch footer!)
