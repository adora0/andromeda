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
SRC := \
	$(ARCH_SRC:%=$(ARCHDIR)/%)

# Generate object paths
# Add source extensions to %.o filter
OBJS := \
$(foreach obj, $(filter %.o, \
	$(SRC:.S=.o) \
), $(OBJDIR)/$(obj))

# Track source includes for assembled objects
INCLUDES 	:= \
$(ARCH_INCLUDES) \
$(wildcard $(INCLUDEDIR)/*.S)

# Flags
CFLAGS		+= -ffreestanding -Wall -Wextra -Wa,-I$(INCLUDEDIR),-I$(ARCH_INCLUDEDIR)
CPPFLAGS	+= -D__is_boot -I$(INCLUDEDIR) -I$(ARCH_INCLUDEDIR)
LDFLAGS		+=

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
$(OBJDIR)/%.o: %.S $(INCLUDES)
	@mkdir -p $(@D)
	@echo "  AS		$(@F)"
	@$(CC) -MD $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

install: env $(KERNEL) $(ARCH_TARGETS)

# Dependencies
-include $(OBJS:.o=.d)
