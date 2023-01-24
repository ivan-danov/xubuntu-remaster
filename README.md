[![GitHub Tag](https://github.com/ivan-danov/xubuntu-remaster/actions/workflows/build_deb.yml/badge.svg)](https://github.com/ivan-danov/xubuntu-remaster/releases)

# xubuntu-remaster

A script to generate a fully-automated ISO image for installing Ubuntu onto a machine without human interaction.
This uses the new autoinstall method for Ubuntu 20.04 and newer.

## 1. Create custom install iso

### 1.1. Create config files.
See examples in /usr/share/doc/xubuntu-remaster/examples

### 1.2. Create custom iso
xubuntu-remaster /usr/share/doc/xubuntu-remaster/examples/simple/simple.conf

## 2. Test custom install iso
xubuntu-remaster simple-*-amd64.iso


## Thanks
This script is based on https://github.com/covertsh/ubuntu-autoinstall-generator

## License
MIT license.
