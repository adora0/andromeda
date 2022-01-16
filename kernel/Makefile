# Module recursed by global Makefile

ARCHDIR := arch/$(ARCH)

# Architecture-specific configuration
# Source files configured with ARCH_SRC
# Custom targets configured with ARCH_TARGETS
-include $(ARCHDIR)/build.mk

# Source files
SRC := \
	$(ARCH_SRC:%=$(ARCHDIR)/%) \
	main.c

INCLUDEDIR	:= $(CURDIR)/include
OBJDIR		:= $(BUILDDIR)/kernel

# Generate object paths
# Add source extensions to %.o filter
OBJS := \
$(OBJDIR)/$(ARCHDIR)/crti.o \
$(OBJDIR)/$(ARCHDIR)/crtbegin.o \
$(foreach obj, $(filter %.o, \
	$(SRC:.c=.o) \
	$(SRC:.S=.o) \
), $(OBJDIR)/$(obj)) \
$(OBJDIR)/$(ARCHDIR)/crtend.o \
$(OBJDIR)/$(ARCHDIR)/crtn.o

# Flags
CFLAGS		+= -ffreestanding -Wall -Wextra
CPPFLAGS	+= -D__is_kernel -I$(INCLUDEDIR) -I$(INSTALL_INCLUDEDIR)
LDFLAGS		+=
LIBS		+= -nostdlib -lk -lgcc

# Targets
.PHONY: all env install install-headers install-kernel

all: env $(KERNEL) $(ARCH_TARGETS)

# Check environment variables
env:
	@test $${ARCH}
	@test $${BUILDDIR}
	@test $${KERNEL}
	@test $${INSTALL_INCLUDEDIR}
	@test $${INSTALL_LIBDIR}
	@test $${INSTALL_BOOTDIR}

# Link kernel objects
# Library arguments must be placed after the kernel objects
$(KERNEL): $(OBJS) $(ARCHDIR)/linker.ld
	@echo "  CC		$(@F)"
	@$(CC) -MD $(CFLAGS) $(LDFLAGS) -T$(ARCHDIR)/linker.ld -o $@ $(OBJS) $(LIBS)

# C runtime generated objects
$(OBJDIR)/$(ARCHDIR)/crtbegin.o $(OBJDIR)/$(ARCHDIR)/crtend.o:
	@mkdir -p $(@D)
	@obj=$$($(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) -print-file-name=$(@F)) && \
		cp "$${obj}" $@

# C source
$(OBJDIR)/%.o: %.c
	@mkdir -p $(@D)
	@echo "  CC		$(@F)"
	@$(CC) -MD $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

# Assembly source
$(OBJDIR)/%.o: %.S
	@mkdir -p $(@D)
	@echo "  AS		$(@F)"
	@$(CC) -MD $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

# Install headers and kernel executable to sysroot
install: install-headers install-kernel

install-headers: env
	@mkdir -p $(INSTALL_INCLUDEDIR)
	@cp -R --preserve=timestamps $(INCLUDEDIR)/. $(INSTALL_INCLUDEDIR)/.

install-kernel: env $(KERNEL) $(ARCH_TARGETS)
	@mkdir -p $(INSTALL_BOOTDIR)
	@cp $(KERNEL) $(INSTALL_BOOTDIR)

# Dependencies
-include $(OBJS:.o=.d)
