#!/bin/sh
if test -n "$1"; then
	PREFIX=$(echo $1)
	$(dirname $0)/setenv.sh PREFIX="$PREFIX"\
	 BINDIR="$PREFIX/bin"
fi