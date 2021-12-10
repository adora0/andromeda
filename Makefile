basedir := $(shell pwd)
envfile := .env
include $(envfile)

PATH := $(PATH):$(PREFIX)/bin
CC := $(TARGET)-gcc
AS := $(TARGET)-as
LD := $(TARGET)-ld

srcdir := ./src
incdir := ./include

# bootloader
boot_sources := $(wildcard $(srcdir)/boot/*.s)
boot_o := $(BUILDDIR)/boot.o
boot_objects := $(boot_o)
boot_ld := $(srcdir)/boot/link.ld
boot_bin := $(BUILDDIR)/boot.bin

# kernel
loader_sources := $(wildcard $(srcdir)/loader/*.s)
loader_o := $(BUILDDIR)/loader.o

module_dirs := $(wildcard $(srcdir)/kernel/*/)
kernel_sources := $(wildcard $(srcdir)/kernel/*.c)
kernel_o := $(BUILDDIR)/kernel.o
kernel_ld := $(srcdir)/kernel/link.ld
kernel_bin := $(BUILDDIR)/kernel.bin

gen_object = $(BUILDDIR)/$(shell basename "$(dir)").o
kernel_objects := $(loader_o) $(kernel_o)
kernel_objects += $(foreach dir,$(module_dirs),$(gen_object))

# compiler flags
ASFLAGS += --warn
CFLAGS += -std=gnu99 -ffreestanding -O2 -nostdlib -Wall -Wextra -lgcc
CFLAGS_KERNEL := $(CFLAGS) -I$(incdir)
CFLAGS_KERNEL_LINK := -T$(kernel_ld) -ffreestanding -O2 -nostdlib -lgcc
LDFLAGS_BOOT := $(LDFLAGS) -T$(boot_ld) --oformat=binary

.SILENT:
all: init boot_bin kernel_bin

init:
	mkdir -p $(BUILDDIR)

boot_o:
	echo "** (AS) bootloader"
	$(AS) -o $(boot_o) $(ASFLAGS) $(boot_sources)

boot_bin: boot_o
	echo "** (LD) link bootloader"
	$(LD) -o $(boot_bin) $(LDFLAGS_BOOT) $(boot_objects)

loader_o:
	echo "** (AS) kernel loader"
	$(AS) -o $(loader_o) $(ASFLAGS) $(loader_sources)

kernel_modules:
	for module in $(module_dirs); do \
		name=$$(basename $${module}); \
		object=$(BUILDDIR)/$${name}.o; \
		sources=$${module}/*.c; \
		echo "** (CC) kernel $${name}"; \
		$(CC) -o $${object} $(CFLAGS_KERNEL) -c $${sources}; \
	done

kernel_o:
	echo "** (CC) kernel"
	$(CC) -o $(kernel_o) $(CFLAGS_KERNEL) -c $(kernel_sources)

kernel_bin: loader_o kernel_modules kernel_o
	echo "** (CC/LD) link kernel"
	$(CC) -o $(kernel_bin) $(CFLAGS_KERNEL_LINK) $(kernel_objects)

clean:
	rm -rf $(BUILDDIR)