BUILDDIR?=.
OBJDIR=$(BUILDDIR)/boot
ARCHDIR=arch/$(ARCH)

include $(ARCHDIR)/make.config
include ./make.config

CFLAGS:=$(CFLAGS) $(BOOT_CFLAGS) $(BOOT_ARCH_CFLAGS)
CPPFLAGS:=$(CPPFLAGS) $(BOOT_CPPFLAGS) $(BOOT_ARCH_CPPFLAGS)
ASFLAGS:=$(ASFLAGS) $(BOOT_ASFLAGS) $(BOOT_ARCH_ASFLAGS)
LDFLAGS:=$(LDFLAGS) $(BOOT_LDFLAGS) $(BOOT_ARCH_LDFLAGS)

SRC=\
$(BOOT_ARCH_SRC) \
$(BOOT_SRC)

INCLUDES=\
$(PROJECT_INCLUDES) \
$(shell find . -name '*.S')

OBJS=$(patsubst %, $(OBJDIR)/%.o, $(SRC))

.PHONY: all clean install install-headers $(ARCH)-image

all: $(BOOT)

$(BOOT): $(OBJS) $(ARCHDIR)/linker.ld
	@$(LD) $(LDFLAGS) -T$(ARCHDIR)/linker.ld -o $@ $(OBJS)

$(OBJDIR)/%.S.o: %.S $(INCLUDES)
	@mkdir -p $(@D)
	@$(CPP) $(CPPFLAGS) -o $(OBJDIR)/$*.s $<
	@$(AS) $(ASFLAGS) -o $@ -c $(OBJDIR)/$*.s
	
i386-image: $(BOOT)
	@dd \
		if=/dev/null \
		of=$(BOOT_IMAGE) \
		bs=$(BOOT_SECTOR_SIZE) \
		count=0 \
		seek=$(BOOT_SECTORS)
	@dd \
		if=$(BOOT) \
		of=$(BOOT_IMAGE) \
		bs=$(BOOT_SECTOR_SIZE) \
		count=1 \
		conv=notrunc
	@mformat -i $(BOOT_IMAGE) \
		-v "$(PROJECT_NAME)" \
		-T $(BOOT_SECTORS) \
		-h $(BOOT_HEADS) \
		-s $(BOOT_TRACK_SECTORS) \
		-r $(BOOT_ROOT_ENTRIES) \
		-L $(BOOT_FAT) \
		-R $(BOOT_RESERVED) \
		-k

clean:
	@rm -f $(BOOT)
	@rm -f $(BOOT_IMAGE)
	@rm -f $(OBJS) *.o */*.o */*/*.o
	@rm -f $(OBJS:.o=.d) *.d */*.d */*/*.d

install: $(BOOT) $(ARCH)-image

install-headers: