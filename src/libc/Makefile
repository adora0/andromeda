BUILDDIR?=.
OBJDIR=$(BUILDDIR)/libc
ARCHDIR=arch/$(ARCH)

CSTD?=gnu99
CFLAGS?=-O2 -g
CPPFLAGS?=
LIBS?=

include $(ARCHDIR)/make.config
include ./make.config

CFLAGS:=$(CFLAGS) $(LIBC_CFLAGS) $(LIB_ARCH_CFLAGS)
CPPFLAGS:=$(CPPFLAGS) $(LIBC_CPPFLAGS) $(LIB_ARCH_CPPFLAGS)
LIBK_CFLAGS:=$(CFLAGS) $(LIBK_CFLAGS) $(KERNEL_CFLAGS) $(KERNEL_ARCH_CFLAGS)
LIBK_CPPFLAGS:=$(CPPFLAGS) $(LIBK_CPPFLAGS) $(KERNEL_CPPFLAGS) $(KERNEL_ARCH_CPPFLAGS)

FREESRC=$(LIBC_ARCH_FREESRC) $(LIBC_FREESRC)
HOSTEDSRC=$(LIBC_ARCH_HOSTEDSRC) $(LIBC_FREESRC)

FREEOBJS=$(patsubst %, $(OBJDIR)/%.o, $(FREESRC))
HOSTEDOBJS=$(patsubst %, $(OBJDIR)/%.o, $(HOSTEDSRC))

OBJS=\
$(FREEOBJS) \
$(HOSTEDOBJS)

INCLUDES=\
$(PROJECT_INCLUDES)

LIBK_OBJS=$(FREEOBJS:.o=.lk.o)

#BINARIES=libc.a libk.a # libc support incomplete
BINARIES=$(OBJDIR)/libk.a

.PHONY: all clean install install-headers install-libs

all: $(BINARIES)

$(OBJDIR)/libc.a: $(OBJS)
	@$(AR) rcs $@ $^

$(OBJDIR)/libk.a: $(LIBK_OBJS)
	@$(AR) rcs $@ $^

$(OBJDIR)/%.c.o: %.c $(INCLUDES)
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) $(CPPFLAGS) -std=$(CSTD) -o $@ -c $<

$(OBJDIR)/%.S.o: %.S $(INCLUDES)
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

$(OBJDIR)/%.c.lk.o: %.c $(INCLUDES)
	@mkdir -p $(@D)
	@$(CC) $(LIBK_CFLAGS) $(LIBK_CPPFLAGS) -std=$(CSTD) -o $@ -c $<

$(OBJDIR)/%.S.lk.o: %.S $(INCLUDES)
	@mkdir -p $(@D)
	@$(CC) $(LIBK_CFLAGS) $(LIBK_CPPFLAGS) -o $@ -c $<

clean:
	@rm -f $(BINARIES) *.a
	@rm -f $(OBJS) $(LIBK_OBJS) *.o */*.o */*/*.o
	@rm -f $(OBJS:.o=.d) $(LIBK_OBJS:.o=.d) *.d */*.d */*/*.d

install: install-headers install-libs

install-headers:
	@mkdir -p $(SYSROOT)/$(INSTALL_INCLUDEDIR)
	@cp -R --preserve=timestamps include/. $(SYSROOT)/$(INSTALL_INCLUDEDIR)/.

install-libs: $(BINARIES)
	@mkdir -p $(SYSROOT)/$(INSTALL_LIBDIR)
	@cp $^ $(SYSROOT)/$(INSTALL_LIBDIR)