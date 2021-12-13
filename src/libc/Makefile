EXECDIR?=../../scripts

DEFAULT_TARGET!=$(EXECDIR)/default_target.sh
TARGET?=DEFAULT_TARGET
TARGET_ARCH!=$(EXECDIR)/target_to_arch.sh $(TARGET)

CSTD?=gnu99
CFLAGS?=-O2 -g
CPPFLAGS?=
LIBS?=

DESTDIR?=.
PREFIX?=/usr/local
EXEC_PREFIX?=$(PREFIX)
INCLUDEDIR?=$(EXEC_PREFIX)/include
LIBDIR?=$(EXEC_PREFIX)/lib

BUILDDIR?=.
OBJDIR=$(BUILDDIR)/libc
ARCHDIR=arch/$(TARGET_ARCH)

CFLAGS:=$(CFLAGS) -ffreestanding -Wall -Wextra
CPPFLAGS:=$(CPPFLAGS) -D__is_libc -Iinclude
LIBK_CFLAGS:=$(CFLAGS)
LIBK_CPPFLAGS:=$(CPPFLAGS) -D__is_libk

include $(ARCHDIR)/make.config

CFLAGS:=$(CFLAGS) $(ARCH_CFLAGS)
CPPFLAGS:=$(CPPFLAGS) $(ARCH_CPPFLAGS)
LIBK_CFLAGS:=$(CFLAGS) $(KERNEL_ARCH_CFLAGS)
LIBK_CPPFLAGS:=$(CPPFLAGS) $(KERNEL_ARCH_CPPFLAGS)

FREESRC=\
$(ARCH_FREESRC) \
string/strlen.c

HOSTEDSRC=\
$(ARCH_HOSTEDSRC)

FREEOBJS=$(patsubst %, $(OBJDIR)/%.o, $(FREESRC))
HOSTEDOBJS=$(patsubst %, $(OBJDIR)/%.o, $(HOSTEDSRC))

OBJS=\
$(FREEOBJS) \
$(HOSTEDOBJS)

LIBK_OBJS=$(FREEOBJS:.o=.lk.o)

#BINARIES=libc.a libk.a # libc support incomplete
BINARIES=$(BUILDDIR)/libk.a

.PHONY: all clean install install-headers install-libs

all: $(BINARIES)

$(BUILDDIR)/libc.a: $(OBJS)
	@$(AR) rcs $@ $^

$(BUILDDIR)/libk.a: $(LIBK_OBJS)
	@$(AR) rcs $@ $^

$(OBJDIR)/%.c.o: %.c
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) $(CPPFLAGS) -std=$(CSTD) -o $@ -c $<

$(OBJDIR)/%.S.o: %.S
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

$(OBJDIR)/%.c.lk.o: %.c
	@mkdir -p $(@D)
	@$(CC) $(LIBK_CFLAGS) $(LIBK_CPPFLAGS) -std=$(CSTD) -o $@ -c $<

$(OBJDIR)/%.S.lk.o: %.S
	@mkdir -p $(@D)
	@$(CC) $(LIBK_CFLAGS) $(LIBK_CPPFLAGS) -o $@ -c $<

clean:
	@rm -f $(BINARIES) *.a
	@rm -f $(OBJS) $(LIBK_OBJS) *.o */*.o */*/*.o
	@rm -f $(OBJS:.o=.d) $(LIBK_OBJS:.o=.d) *.d */*.d */*/*.d

install: install-headers install-libs

install-headers:
	@mkdir -p $(DESTDIR)$(INCLUDEDIR)
	@cp -R --preserve=timestamps include/. $(DESTDIR)$(INCLUDEDIR)/.

install-libs: $(BINARIES)
	@mkdir -p $(DESTDIR)$(LIBDIR)
	@cp $^ $(DESTDIR)$(LIBDIR)