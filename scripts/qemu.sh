#!/bin/sh
set -e
EXECDIR=$(realpath $(dirname $0))
. $EXECDIR/config.sh

ARCH=$($EXECDIR/target_to_arch.sh $TARGET)

if test ! -e "$BUILDDIR/$NAME.iso"; then
	$EXECDIR/build_image.sh
fi

qemu-system-${ARCH} -cdrom "$BUILDDIR/$NAME.iso"