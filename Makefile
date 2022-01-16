# Environment variables pre-configured by configuration script
-include .env.mk

# Build configuration
-include build.mk

# Synchronus modules to be compiled
MODULES		:= libc kernel boot

# Automatic and fallback variables
export TARGET		?= $$(uname -m)
export ARCH			?= $(TARGET)

export BUILDDIR		?= build
export SYSROOT		?= $(BUILDDIR)/sysroot

export INSTALL_INCLUDEDIR	:= $(SYSROOT)/usr/include
export INSTALL_LIBDIR		:= $(SYSROOT)/usr/lib
export INSTALL_BOOTDIR		:= $(SYSROOT)/boot

# Cross-compiler toolchain
export AR		:= ${TARGET}-ar
export AS		:= ${TARGET}-as
export CC		:= ${TARGET}-gcc
export CPP		:= ${TARGET}-cpp
export LD		:= ${TARGET}-ld

ifdef PREFIX
export AR		:= $(PREFIX)/bin/$(AR)
export AS		:= $(PREFIX)/bin/$(AS)
export CC		:= $(PREFIX)/bin/$(CC)
export CPP		:= $(PREFIX)/bin/$(CPP)
export LD		:= $(PREFIX)/bin/$(LD)
endif

# Global flags
# General options configured in build.mk
export CFLAGS	+= --sysroot=$(SYSROOT)
export CPPFLAGS	+= -I$(CURDIR)/include
export ASFLAGS	+=
export LDFLAGS	+=

# Output files required by modules
export KERNEL	:= $(BUILDDIR)/kernel.elf
export BOOT		:= $(BUILDDIR)/boot.img

# File extensions removed by clean target
clean_SUFFIXES		:= .o .d .bin .img

# Targets
.PHONY: all $(MODULES) test clean

all: $(MODULES)

# Recurse into modules
$(MODULES):
	@echo "  MK		$@"
	@$(MAKE) install -C $@

test: $(MODULES)
	@qemu-system-$(ARCH) \
		-drive file=$(BOOT),bus=0,index=0,format=raw,if=floppy \
		-boot order=a

debug: $(MODULES)
	@qemu-system-$(ARCH) \
		-drive file=$(BOOT),bus=0,index=0,format=raw,if=floppy \
		-boot order=a \
		-chardev socket,path=.gdb.socket,server=on,wait=off,id=gdb0 \
		-gdb chardev:gdb0 \
		-S & \
	gdb -ex 'file $(KERNEL)' -ex 'target remote .gdb.socket'; \
		kill $$(jobs -p) 2>/dev/null; \
		rm -f .gdb.socket

clean:
	$(RM) $(foreach suffix, $(clean_SUFFIXES), $(shell find $(BUILDDIR) -name '*$(suffix)'))
