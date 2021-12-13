BUILDDIR?=.
OBJDIR=$(BUILDDIR)/boot
ARCHDIR=arch/$(ARCH)

include $(ARCHDIR)/make.config
include ./make.config

ASFLAGS:=$(ASFLAGS) $(BOOT_ASFLAGS) $(BOOT_ARCH_ASFLAGS)
LDFLAGS:=$(LDFLAGS) $(BOOT_LDFLAGS) $(BOOT_ARCH_LDFLAGS)

SRC=\
$(BOOT_ARCH_SRC) \
$(BOOT_SRC)

OBJS=$(patsubst %, $(OBJDIR)/%.o, $(SRC))

.PHONY: all clean install-headers

all: $(BOOT)

$(BOOT): $(OBJS) $(ARCHDIR)/linker.ld
	@$(LD) $(LDFLAGS) -T$(ARCHDIR)/linker.ld -o $@ $(OBJS)

$(OBJDIR)/%.S.o: %.S
	@mkdir -p $(@D)
	@$(AS) $(ASFLAGS) -o $@ $<

clean:
	@rm -f $(BOOT)
	@rm -f $(OBJS) *.o */*.o */*/*.o
	@rm -f $(OBJS:.o=.d) *.d */*.d */*/*.d

install: $(BOOT)

install-headers: