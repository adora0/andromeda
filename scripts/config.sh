envfile=$(pwd)/.env
if test -e $envfile; then
	. $envfile
fi

export EXECDIR=${EXECDIR:-$( realpath $(dirname $0) )}

export MAKE=${MAKE:-make}
export TARGET=${TARGET:-$($EXECDIR/default_target.sh)}
export NAME=cosmos

export PREFIX=${PREFIX:-/usr}
export EXEC_PREFIX=${EXEC_PREFIX:-$PREFIX}
export BOOTDIR=${BOOTDIR:-/boot}
export LIBDIR=${LIBDIR:-$EXEC_PREFIX/lib}
export INCLUDEDIR=${INCLUDEDIR:-$EXEC_PREFIX/include}

export SRCDIR=./src
export BUILDDIR=${BUILDDIR:-$(pwd)/build}
export OBJDIR=$BUILDDIR
export IMGDIR=$BUILDDIR/image
export SYSROOT="$BUILDDIR/sysroot"
export DESTDIR=$SYSROOT

BINDIR=$PREFIX/bin
if test "${PATH#*$BINDIR}" = "$PATH"; then
	export PATH=$BINDIR:$PATH
fi

if test -z $NOCC; then
	export AR=${TARGET}-ar
	export AS=${TARGET}-as
	export CC=${TARGET}-gcc
	export LD=${TARGET}-ld

	export CFLAGS='-O2 -g'
	export CPPFLAGS=''
	export LDFLAGS=''
	export ASFLAGS='--warn'

	# Configure cross-compiler to use desired system root.
	# The build should be installed to this directory.
	export CC="$CC --sysroot=$SYSROOT"

	# Add system include directory to -elf gcc targets
	# due to configuration with --without-headers rather than --with-sysroot
	if echo "$HOST" | grep -Eq -- '-elf($|-)'; then
		export CC="$CC -isystem=$INCLUDEDIR"
	fi
fi

COMPONENTS="boot libc kernel"

HEADER_COMPONENTS="libc kernel"

SRC_COMPONENTS=$(for COMPONENT in $COMPONENTS; do
	echo "$SRCDIR/$COMPONENT"
done)

SRC_HEADER_COMPONENTS=$(for COMPONENT in $HEADER_COMPONENTS; do
	echo "$SRCDIR/$COMPONENT"
done)