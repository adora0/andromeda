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

export AR=${TARGET}-ar
export AS=${TARGET}-as
export CC=${TARGET}-gcc
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

.PHONY: all clean $(COMPONENTS) image qemu

all: $(COMPONENTS)

$(COMPONENTS):
	@$(MAKE) install -C $(SRCDIR)/$@

image: $(COMPONENTS)
	@mkdir -p $(IMAGEDIR)/boot/grub
	@cp $(KERNEL) $(IMAGEDIR)/boot/$(KERNEL_NAME)
	@eval "echo \"$$(cat $(TOOLSDIR)/image/grub.cfg.in)\"" \
		>$(IMAGEDIR)/boot/grub/grub.cfg
	@grub-mkrescue -o $(IMAGE) $(IMAGEDIR)

qemu: image
	@qemu-system-$(ARCH) -cdrom $(IMAGE)

debug: image
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