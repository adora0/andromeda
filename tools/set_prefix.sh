#!/bin/sh
if test -n "$1"; then
	PREFIX=$(echo $1)
	cat >.env.local <<EOF
PREFIX=$PREFIX
BINDIR=$PREFIX/bin
EOF
fi