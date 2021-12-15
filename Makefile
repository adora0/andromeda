include ./make.config

BUILDDIR?=./build
IMAGEDIR?=$(BUILDDIR)/image

CLEAN_COMPONENTS:=$(addsuffix _clean, $(COMPONENTS))

export ARCH:=$(shell \
if echo "$(TARGET)" | grep -Eq 'i[[:digit:]]86-'; then \
	echo i386; \
else \
	echo "$(TARGET)" | grep -Eo '^[[:alnum:]_]*'; \
fi)

export PATH:=$(shell \
PATH="$(PATH)"; \
BINDIR="$(BINDIR)"; \
if test "$${PATH#*"$$BINDIR"}" = "$$PATH"; then \
	echo "$$BINDIR:$$PATH"; \
fi)

CFLAGS:=$(CFLAGS)
CPPFLAGS:=$(CPPFLAGS) -I$(PROJECT_INCLUDEDIR)
LDFLAGS:=$(LDFLAGS)
ASFLAGS:=$(ASFLAGS)

PROJECT_INCLUDES:=$(shell find $(PROJECT_INCLUDEDIR) -name '*.h')

export AR=${TARGET}-ar
export AS=${TARGET}-as
export CC=${TARGET}-gcc
export CPP=${TARGET}-cpp
export LD=${TARGET}-ld

export CFLAGS
export CPPFLAGS
export LDFLAGS
export ASFLAGS

export SYSROOT
export INSTALL_PREFIX
export INSTALL_EXEC_PREFIX
export INSTALL_INCLUDEDIR
export INSTALL_LIBDIR
export INSTALL_BOOTDIR

export BUILDDIR
export PROJECT_NAME
export PROJECT_INCLUDES

export BOOT_NAME=boot.bin
export KERNEL_NAME=kernel.bin

export BOOT=$(BUILDDIR)/$(BOOT_NAME)
export KERNEL=$(BUILDDIR)/$(KERNEL_NAME)
export IMAGE=$(BUILDDIR)/$(PROJECT_NAME).iso
export BOOT_IMAGE=$(BUILDDIR)/$(PROJECT_NAME).img

# Configure the cross-compiler to use the desired system root.
# The build should be installed to this directory.
export CC:=$(CC) --sysroot=$(SYSROOT)

# Add system include directory to -elf gcc targets
# due to configuration with --without-headers rather than --with-sysroot
export CC:=$(shell \
if echo "$(CC)" | grep -Eq -- '-elf($|-)'; then \
	echo "$(CC) -isystem=$INCLUDEDIR"; \
fi)

.PHONY: all clean $(COMPONENTS) \
kernel-image qemu-kernel debug-kernel \
image $(ARCH)-image qemu debug

all: $(COMPONENTS)

$(COMPONENTS):
	@$(MAKE) install -C $(SRCDIR)/$@

image: $(ARCH)-image

i386-image: $(COMPONENTS)
	@mmd -i $(BOOT_IMAGE) ::boot
	@mcopy -i $(BOOT_IMAGE) $(KERNEL) ::boot/kernel.bin

qemu: image
	@qemu-system-$(ARCH) \
		-drive file=$(BOOT_IMAGE),format=raw,index=0,media=disk

debug: image
	@qemu-system-$(ARCH) \
		-drive file=$(BOOT_IMAGE),format=raw,index=0,media=disk \
		-chardev socket,path=.gdb.socket,server=on,wait=off,id=gdb0 \
		-gdb chardev:gdb0 \
		-S & \
		gdb -ex 'file $(KERNEL)' -ex 'target remote .gdb.socket'; \
		kill $$(jobs -p) 2>/dev/null; \
		rm -f .gdb.socket

kernel-image: $(COMPONENTS)
	@mkdir -p $(IMAGEDIR)/boot/grub
	@cp $(KERNEL) $(IMAGEDIR)/boot/$(KERNEL_NAME)
	@eval "echo \"$$(cat $(TOOLSDIR)/image/grub.cfg.in)\"" \
		>$(IMAGEDIR)/boot/grub/grub.cfg
	@grub-mkrescue -o $(IMAGE) $(IMAGEDIR)

qemu-kernel: kernel-image
	@qemu-system-$(ARCH) -cdrom $(IMAGE)

debug-kernel: kernel-image
	@qemu-system-$(ARCH) \
		-cdrom $(IMAGE) \
		-chardev socket,path=.gdb.socket,server=on,wait=off,id=gdb0 \
		-gdb chardev:gdb0 \
		-S & \
		gdb -ex 'file $(KERNEL)' -ex 'target remote .gdb.socket'; \
		kill $$(jobs -p) 2>/dev/null; \
		rm -f .gdb.socket

%_clean: $(SRCDIR)/%
	@$(MAKE) clean -C $<

clean: $(CLEAN_COMPONENTS)
	@rm -rf $(BUILDDIR)