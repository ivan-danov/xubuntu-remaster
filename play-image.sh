#!/bin/bash -x
usage()
{
	echo "Usage: $0 <iso file>"
	exit 1
}
if [ $# -ne 1 ]; then
	usage
fi
if [ ! -f $1 ]; then
	usage
fi
if [ ! -x /usr/bin/qemu-img ]; then
	sudo apt-get -y install qemu-utils
fi
if [ ! -x /usr/bin/qemu-system-x86_64 ]; then
	sudo apt-get -y install qemu-system-x86
fi
if [ ! -f /usr/share/ovmf/OVMF.fd ]; then
	sudo apt-get -y install ovmf
fi
if [ ! -x /usr/bin/swtpm ]; then
	sudo apt-get -y install swtpm
fi

# TPMDIR=/tmp/tmp.play_image
TPMDIR=$(mktemp -d /tmp/tmp.XXXXXXXXXX)
# # if [ -d ${TPMDIR} ]; then
# # 	rm -rf ${TPMDIR}
# # fi
if [ ! -d ${TPMDIR} ]; then
	mkdir ${TPMDIR}
fi

echo "Create empty disk"
rm -f test.vmdk
qemu-img create -f vmdk test.vmdk 11G

# -device qxl-vga,vgamem_mb=64,ram_size_mb=256,vram_size_mb=128,max_outputs=2 \
# -display gtk,gl=on

QEMU_MACHINE="-cpu host -smp 4 -m 4096 -enable-kvm -bios /usr/share/ovmf/OVMF.fd"
QEMU_TPM="-chardev socket,id=chrtpm,path=${TPMDIR}/swtpm-sock -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0"

QEMU_VIDEO="-vga virtio -device virtio-vga,max_outputs=2"
# QEMU_VIDEO="-vga qxl -device qxl"

QEMU_NET="-nic none"
# QEMU_NET="-netdev user,id=net0 -device e1000,netdev=net0"
# QEMU_NET="-netdev user,id=net0,hostfwd=tcp:127.0.0.1:43211-:43210 -device e1000,netdev=net0 "

echo "test install"
swtpm socket --tpmstate dir=${TPMDIR} \
	--ctrl type=unixio,path=${TPMDIR}/swtpm-sock \
	--tpm2 \
	--daemon \
	--log level=20
qemu-system-x86_64 \
	${QEMU_MACHINE} \
	${QEMU_VIDEO} \
	${QEMU_NET} \
	-drive format=vmdk,file=test.vmdk \
	-display sdl,gl=on \
	${QEMU_TPM} \
	-drive file=$1,media=cdrom,readonly=on -boot c

echo "test start"
swtpm socket --tpmstate dir=${TPMDIR} \
	--ctrl type=unixio,path=${TPMDIR}/swtpm-sock \
	--tpm2 \
	--daemon \
	--log level=20
qemu-system-x86_64 \
	${QEMU_MACHINE} \
	${QEMU_VIDEO} \
	${QEMU_NET} \
	-drive format=vmdk,file=test.vmdk \
	-display sdl,gl=on \
	${QEMU_TPM}

echo "Clean"
if [ -d ${TPMDIR} ]; then
	rm -rf ${TPMDIR}
fi
rm -f test.vmdk
