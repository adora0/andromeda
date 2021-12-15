BUILDDIR?=.
OBJDIR=$(BUILDDIR)/boot
ARCHDIR=arch/$(ARCH)

include ./make.config

CFLAGS:=$(CFLAGS) $(BOOT_CFLAGS)
CPPFLAGS:=$(CPPFLAGS) $(BOOT_CPPFLAGS) -I$(shell pwd)/include
ASFLAGS:=$(ASFLAGS) $(BOOT_ASFLAGS)
LDFLAGS:=$(LDFLAGS) $(BOOT_LDFLAGS)

export BUILDDIR
export OBJDIR
export ARCHDIR

export CFLAGS
export CPPFLAGS
export ASFLAGS
export LDFLAGS

.PHONY: all install $(ARCHDIR) install-headers

all: $(ARCHDIR)

$(ARCHDIR):
	@$(MAKE) install -C $@

clean:
	@$(MAKE) clean -C $(ARCHDIR)

install: $(ARCHDIR)
install-headers: