EXECDIR?=../../scripts

DEFAULT_TARGET!=$(EXECDIR)/default_target.sh
TARGET?=DEFAULT_TARGET
TARGET_ARCH!=$(EXECDIR)/target_to_arch.sh $(TARGET)

BUILDDIR?=.
OBJDIR=$(BUILDDIR)/boot
ARCHDIR=arch/$(TARGET_ARCH)

ASFLAGS:=$(ASFLAGS)
LDFLAGS:=$(LDFLAGS)

include $(ARCHDIR)/make.config

LDFLAGS:=$(LDFLAGS) $(BOOT_ARCH_LDFLAGS)

SRC=\
$(BOOT_ARCH_SRC) \
$(LIBS)

OBJS=$(patsubst %, $(OBJDIR)/%.o, $(SRC))

BOOT=$(BUILDDIR)/$(NAME)-boot

.PHONY: all clean

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