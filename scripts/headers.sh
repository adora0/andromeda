#!/bin/sh
set -e
EXECDIR=$(realpath $(dirname $0))
. $EXECDIR/config.sh

mkdir -p $BUILDDIR $OBJDIR

for COMPONENT in $SRC_HEADER_COMPONENTS; do
	(cd $COMPONENT && $MAKE install-headers)
done