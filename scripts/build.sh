#!/bin/sh
set -e
EXECDIR=$(realpath $(dirname $0))
. $EXECDIR/headers.sh

for COMPONENT in $SRC_COMPONENTS; do
	(cd $COMPONENT && $MAKE install)
done