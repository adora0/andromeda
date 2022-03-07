# Module recursed by global Makefile

ARCHDIR := arch/$(ARCH)

INCLUDEDIR		:= $(CURDIR)/include
ARCH_INCLUDEDIR	:= $(ARCHDIR)/include
OBJDIR		:= $(BUILDDIR)/boot

# Architecture-specific configuration
# Source files configured with ARCH_SRC
# Custom targets configured with ARCH_TARGETS
-include $(ARCHDIR)/build.mk

# Source files
# Architecture-specific source configured separately
SRC := 

# Generate object paths
# Add source extensions to %.o filter
OBJS := \
$(foreach obj, $(filter %.o, \
	$(SRC:.S=.o) \
), $(OBJDIR)/$(obj))

# Flags
CFLAGS		+= -ffreestanding -Wall -Wextra -Wa,-I$(ARCHDIR)
CPPFLAGS	+= -D__is_boot -I$(INCLUDEDIR)
LDFLAGS		+=
LIBS		+= -nostdlib -lgcc

# Targets
.PHONY: all env install

# Bootloader link stage defined in ARCH_TARGETS
# (architecture-specific)
all: env $(ARCH_TARGETS)

# Check environment variables
env:
	@test $${ARCH}
	@test $${BUILDDIR}
	@test $${BOOT}
	@test $${KERNEL}
	@test $${INSTALL_INCLUDEDIR}
	@test $${INSTALL_LIBDIR}
	@test $${INSTALL_BOOTDIR}

# Assembly source
$(OBJDIR)/%.o: %.S
	@mkdir -p $(@D)
	@echo "  CC		$(@F)"
	@$(CC) -MD $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

# C source
$(OBJDIR)/%.o: %.c
	@mkdir -p $(@D)
	@echo "  CC		$(@F)"
	@$(CC) -MD $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

install: env $(KERNEL) $(ARCH_TARGETS)

# Dependencies
-include $(OBJS:.o=.d)