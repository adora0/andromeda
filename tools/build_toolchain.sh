#!/bin/sh
if test -f ./envfile; then . ./envfile; fi
if test -f ./.env.local; then . ./.env.local; fi

TARGET=${TARGET-$DEFAULT_TARGET}
BUILDDIR=${BUILDDIR-$DEFAULT_BUILDDIR}/tools

server='ftp://ftp.gnu.org'
binutils_version='2.37'
binutils_url="${server}/gnu/binutils/binutils-${binutils_version}.tar.gz"
gcc_version='11.2.0'
gcc_url="${server}/gnu/gcc/gcc-${gcc_version}/gcc-${gcc_version}.tar.gz"

binutils_out="binutils-${binutils_version}.tar.gz"
binutils_outdir="binutils-${binutils_version}"
binutils_builddir="${binutils_outdir}-build"
gcc_out="gcc-${gcc_version}.tar.gz"
gcc_outdir="gcc-${gcc_version}"
gcc_builddir="${gcc_outdir}-build"

mkdir -p "$BUILDDIR" "$PREFIX"

(
	cd "$BUILDDIR"
	
	# build binutils
	curl -o "$binutils_out" "$binutils_url"
	mkdir -p "$binutils_outdir" "$binutils_builddir"
	tar -xzf "$binutils_out"
	(
		cd "$binutils_builddir"
		../$binutils_outdir/configure --prefix="$PREFIX" --target=$TARGET
		make
		make install
	)

	# build gcc
	curl -o "$gcc_out" "$gcc_url"
	mkdir -p "$gcc_outdir" "$gcc_builddir"
	tar -xzf "$gcc_out"
	(
		cd "$gcc_builddir"
		../$gcc_outdir/configure --prefix="$PREFIX" --target=$TARGET
		make all-gcc
		make all-target-libgcc
		make install-gcc
		make install-target-libgcc
	)
)