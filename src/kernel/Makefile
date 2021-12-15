BUILDDIR?=.
OBJDIR=$(BUILDDIR)/kernel
ARCHDIR=arch/$(ARCH)

CSTD?=gnu99
CFLAGS?=-O2 -g
CPPFLAGS?=
LIBS?=

include $(ARCHDIR)/make.config
include ./make.config

CFLAGS:=$(CFLAGS) $(KERNEL_CFLAGS) $(KERNEL_ARCH_CFLAGS)
CPPFLAGS:=$(CPPFLAGS) $(KERNEL_CPPFLAGS) $(KERNEL_ARCH_CPPFLAGS)
LDFLAGS:=$(LDFLAGS) $(KERNEL_LDFLAGS) $(KERNEL_ARCH_LDFLAGS)
LIBS:=$(LIBS) $(KERNEL_LIBS) $(KERNEL_ARCH_LIBS)

SRC=$(KERNEL_ARCH_SRC) $(KERNEL_SRC)

OBJS=\
$(OBJDIR)/$(ARCHDIR)/crti.S.o \
$(OBJDIR)/$(ARCHDIR)/crtbegin.o \
$(patsubst %, $(OBJDIR)/%.o, $(SRC)) \
$(OBJDIR)/$(ARCHDIR)/crtend.o \
$(OBJDIR)/$(ARCHDIR)/crtn.S.o

INCLUDES=\
$(PROJECT_INCLUDES)

.PHONY: all clean install install-headers install-kernel

all: $(BUILDDIR)/$(NAME).kernel

$(KERNEL): $(OBJS) $(LIB_OBJS) $(ARCHDIR)/linker.ld
	@$(CC) $(CFLAGS) $(LDFLAGS) -T$(ARCHDIR)/linker.ld -o $@ $(OBJS) $(LIBS)
	@grub-file --is-x86-multiboot $(KERNEL)

$(OBJDIR)/$(ARCHDIR)/crtbegin.o $(OBJDIR)/$(ARCHDIR)/crtend.o:
	@OBJ=`$(CC) $(CFLAGS) $(LDFLAGS) -print-file-name=$(@F)` && \
	cp "$$OBJ" $@

$(OBJDIR)/%.c.o: %.c $(INCLUDES)
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) $(CPPFLAGS) -std=$(CSTD) -o $@ -c $<

$(OBJDIR)/%.S.o: %.S $(INCLUDES)
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

clean:
	@rm -f $(KERNEL)
	@rm -f $(OBJS) *.o */*.o */*/*.o
	@rm -f $(OBJS:.o=.d) *.d */*.d */*/*.d

install: install-headers install-kernel

install-headers:
	@mkdir -p $(SYSROOT)/$(INSTALL_INCLUDEDIR)
	@cp -R --preserve=timestamps include/. $(SYSROOT)/$(INSTALL_INCLUDEDIR)/.

install-kernel: $(KERNEL)
	@mkdir -p $(SYSROOT)/$(INSTALL_BOOTDIR)
	@cp $^ $(SYSROOT)/$(INSTALL_BOOTDIR)