basedir := $(shell pwd)
envfile := $(basedir)/.env
include $(envfile)

PATH := $(PATH):$(PREFIX)/bin
CC := $(TARGET)-gcc
AS := $(TARGET)-as
LD := $(TARGET)-ld

srcdir := $(basedir)/src
incdir := $(basedir)/include

ASFLAGS += --warn
CFLAGS += -std=gnu99 -ffreestanding -O2 -nostdlib -Wall -Wextra -lgcc

loader_o := $(BUILDDIR)/loader.o
kernel_o := $(BUILDDIR)/kernel.o
objects := $(loader_o) $(kernel_o)

loader_sources := $(wildcard $(srcdir)/loader/*.s)
kernel_sources := $(wildcard $(srcdir)/kernel/*.c)

kernel_ld := $(srcdir)/kernel/link.ld
exec := $(BUILDDIR)/kernel.bin

.SILENT:
all: init kernel_bin

init:
	mkdir -p $(BUILDDIR)

loader_o:
	echo "** (AS) loader"
	$(AS) -o $(loader_o) $(ASFLAGS) $(loader_sources)

kernel_o:
	echo "** (CC) kernel"
	$(CC) -o $(kernel_o) -I$(incdir) $(CFLAGS) -c $(kernel_sources)

kernel_bin: loader_o kernel_o
	echo "** (CC) link kernel"
	$(CC) -o $(exec) -T $(kernel_ld) $(CFLAGS) $(objects)

clean:
	rm -rf $(BUILDDIR)