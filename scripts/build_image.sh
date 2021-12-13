#!/bin/sh
set -e
EXECDIR=$(realpath $(dirname $0))
. $EXECDIR/build.sh

mkdir -p $IMGDIR/boot/grub
cp ${SYSROOT}${BOOTDIR}/$NAME-kernel $IMGDIR/boot/$NAME-kernel

cat >$IMGDIR/boot/grub/grub.cfg <<EOF
set timeout=0
menuentry "$NAME" {
	multiboot /boot/$NAME-kernel
}
EOF

grub-mkrescue -o $BUILDDIR/$NAME.iso $IMGDIR