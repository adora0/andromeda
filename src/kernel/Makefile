EXECDIR?=../../scripts

DEFAULT_TARGET!=$(EXECDIR)/default_target.sh
TARGET?=DEFAULT_TARGET
TARGET_ARCH!=$(EXECDIR)/target_to_arch.sh $(TARGET)

CSTD?=gnu99
CFLAGS?=-O2 -g
CPPFLAGS?=
LDFLAGS?=
LIBS?=

DESTDIR?=.
PREFIX?=/usr/local
EXEC_PREFIX?=$(PREFIX)
INCLUDEDIR?=$(EXEC_PREFIX)/include
BOOTDIR?=$(EXEC_PREFIX)/boot

BUILDDIR?=.
OBJDIR=$(BUILDDIR)/kernel
LIB_OBJDIR=$(BUILDDIR)/libc
ARCHDIR=arch/$(TARGET_ARCH)

CFLAGS:=$(CFLAGS) -ffreestanding -Wall -Wextra
CPPFLAGS:=$(CPPFLAGS) -D__is_kernel -Iinclude -I../libc/include
LDFLAGS:=$(LDFLAGS)
LIBS:=$(LIBS) -nostdlib -L$(BUILDDIR) -lk -lgcc

include $(ARCHDIR)/make.config

CFLAGS:=$(CFLAGS) $(KERNEL_ARCH_CFLAGS)
CPPFLAGS:=$(CPPFLAGS) $(KERNEL_ARCH_CPPFLAGS)
LDFLAGS:=$(LDFLAGS) $(KERNEL_ARCH_LDFLAGS)
LIBS:=$(LIBS) $(KERNEL_ARCH_LIBS)

KERNEL_SRC=\
$(KERNEL_ARCH_SRC) \
kernel.c

OBJS=\
$(OBJDIR)/$(ARCHDIR)/crti.S.o \
$(OBJDIR)/$(ARCHDIR)/crtbegin.o \
$(patsubst %, $(OBJDIR)/%.o, $(KERNEL_SRC)) \
$(OBJDIR)/$(ARCHDIR)/crtend.o \
$(OBJDIR)/$(ARCHDIR)/crtn.S.o

KERNEL=$(BUILDDIR)/$(NAME)-kernel

.PHONY: all clean install install-headers install-kernel

all: $(BUILDDIR)/$(NAME).kernel

$(KERNEL): $(OBJS) $(LIB_OBJS) $(ARCHDIR)/linker.ld
	@$(CC) $(CFLAGS) $(LDFLAGS) -T$(ARCHDIR)/linker.ld -o $@ $(OBJS) $(LIBS)
	@grub-file --is-x86-multiboot $(KERNEL)

$(OBJDIR)/$(ARCHDIR)/crtbegin.o $(OBJDIR)/$(ARCHDIR)/crtend.o:
	@OBJ=`$(CC) $(CFLAGS) $(LDFLAGS) -print-file-name=$(@F)` && \
	cp "$$OBJ" $@

$(OBJDIR)/%.c.o: %.c
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) $(CPPFLAGS) -std=$(CSTD) -o $@ -c $<

$(OBJDIR)/%.S.o: %.S
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

clean:
	@rm -f $(KERNEL)
	@rm -f $(OBJS) *.o */*.o */*/*.o
	@rm -f $(OBJS:.o=.d) *.d */*.d */*/*.d

install: install-headers install-kernel

install-headers:
	@mkdir -p $(DESTDIR)$(INCLUDEDIR)
	@cp -R --preserve=timestamps include/. $(DESTDIR)$(INCLUDEDIR)/.

install-kernel: $(KERNEL)
	@mkdir -p $(DESTDIR)$(BOOTDIR)
	@cp $^ $(DESTDIR)$(BOOTDIR)