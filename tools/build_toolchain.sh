#!/bin/sh
## Retrieve and build the OS toolchain

envfile=./.env


# URLs
server="ftp://ftp.gnu.org"
binutils_version="2.37"
binutils_url="${server}/gnu/binutils/binutils-${binutils_version}.tar.gz"
gcc_version="11.2.0"
gcc_url="${server}/gnu/gcc/gcc-${gcc_version}/gcc-${gcc_version}.tar.gz"

binutils_out="binutils-${binutils_version}.tar.gz"
binutils_outdir="binutils-${binutils_version}"
binutils_builddir="${binutils_outdir}-build"
gcc_out="gcc-${gcc_version}.tar.gz"
gcc_outdir="gcc-${gcc_version}"
gcc_builddir="${gcc_outdir}-build"


# Get environment variables set by the configuration script
test ! -e "${envfile}"  || . "${envfile}"
test -n "${TARGET-}"    || exit
test -n "${BUILDDIR-}"  || exit
test -n "${PREFIX-}"    || exit


mkdir -p "$BUILDDIR" "$PREFIX"

(
	cd "$BUILDDIR"

	# Get binutils
	curl -o "${binutils_out}" "${binutils_url}"
	mkdir -p "${binutils_outdir}" "${binutils_builddir}"
	tar -xzf "${binutils_out}"
	(
		cd "${binutils_builddir}"

        # Build
		../${binutils_outdir}/configure --prefix="${PREFIX}" --target=${TARGET}
		make
		make install
	)


	# Get gcc
	curl -o "${gcc_out}" "${gcc_url}"
	mkdir -p "${gcc_outdir}" "${gcc_builddir}"
	tar -xzf "${gcc_out}"
	(
		cd "${gcc_builddir}"

        # Build
		../${gcc_outdir}/configure --prefix="${PREFIX}" --target=${TARGET}
        make all-gcc
		make all-target-libgcc
		make install-gcc
		make install-target-libgcc
	)
)