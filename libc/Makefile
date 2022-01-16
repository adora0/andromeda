# Module recursed by global Makefile

# libc: runtime library (hosted)
# libk: kernel library (freestanding)

ARCHDIR := arch/$(ARCH)

# Architecture-specific configuration
# Source files configured with ARCH_FREESRC and ARCH_HOSTEDSRC
-include $(ARCHDIR)/build.mk

# Freestanding source files (libc, libk)
FREESRC := \
	$(ARCH_FREESRC:%=$(ARCHDIR)/%) \
	string/strlen.c

# Hosted source files (libc)
HOSTEDSRC 	:= \
	$(ARCH_HOSTEDSRC:%=$(ARCHDIR)/%)

INCLUDEDIR	:= $(CURDIR)/include
OBJDIR		:= $(BUILDDIR)/libc

# Generate object paths
# Add source extensions to %.o filter
FREEOBJ := $(foreach obj, $(filter %.o, \
	$(FREESRC:.c=.o) \
), $(OBJDIR)/$(obj))

HOSTEDOBJ := $(foreach obj, $(filter %.o, \
	$(HOSTEDSRC:.c=.o) \
), $(OBJDIR)/$(obj))

OBJS			:= $(FREEOBJ) $(HOSTEDOBJ)
libk_OBJS		:= $(FREEOBJ:.o=.lk.o)

# Flags
CFLAGS			+= -ffreestanding -Wall -Wextra
CPPFLAGS		+= -D__is_libc -I$(INCLUDEDIR)
libk_CFLAGS		:= $(CFLAGS)
libk_CPPFLAGS	:= $(CPPFLAGS) -D__is_libk

# Output library paths
# Add libc when complete
LIBS		:= $(OBJDIR)/libk.a

# Targets
.PHONY: all env install install-headers install-libs

all: env $(LIBS)

# Check envrionment variables
env:
	@test $${ARCH}
	@test $${BUILDDIR}
	@test $${INSTALL_INCLUDEDIR}
	@test $${INSTALL_LIBDIR}

# Library archives
$(OBJDIR)/libc.a: $(OBJS)
	@echo "  AR		$(@F)"
	@$(AR) rcs $@ $^

$(OBJDIR)/libk.a: $(libk_OBJS)
	@echo "  AR		$(@F)"
	@$(AR) rcs $@ $^

# C source (libc)
$(OBJDIR)/%.o: %.c
	@mkdir -p $(@D)
	@echo "  CC		$(@F)"
	@$(CC) -MD $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

# C source (libk)
$(OBJDIR)/%.lk.o: %.c
	@mkdir -p $(@D)
	@echo "  CC		$(@F)"
	@$(CC) -MD $(libk_CFLAGS) $(libk_CPPFLAGS) -o $@ -c $<

# Install headers and libraries to sysroot
install: install-headers install-libs

install-headers: env
	@mkdir -p $(INSTALL_INCLUDEDIR)
	@cp -R --preserve=timestamps $(INCLUDEDIR)/. $(INSTALL_INCLUDEDIR)/.

install-libs: env $(LIBS)
	@mkdir -p $(INSTALL_LIBDIR)
	@cp $(LIBS) $(INSTALL_LIBDIR)

# Dependencies
-include $(OBJS:.o=.d)
-include $(libk_OBJS:.o=.d)
