#!/bin/sh
set -e
EXECDIR=$(realpath $(dirname $0))
. $EXECDIR/config.sh

for COMPONENT in $SRC_COMPONENTS; do
	echo $COMPONENT
	(cd $COMPONENT && make clean)
done

rm -rf $BUILDDIR