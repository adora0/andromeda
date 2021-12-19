include ./make.config

BOOT_STAGE1:=$(OBJDIR)/boot.bin
BOOT_STAGE2:=$(OBJDIR)/loader.bin

export BOOT_STAGE1
export BOOT_STAGE2

.PHONY: all clean install install-headers $(ARCH)-image

all: $(BOOT_STAGE1) $(BOOT_STAGE2)

$(BOOT_STAGE1):
	@$(MAKE) -C $(STAGE1_SRCDIR)

$(BOOT_STAGE2):
	@$(MAKE) -C $(STAGE2_SRCDIR)

$(ARCH)-image: $(BOOT_STAGE1) $(BOOT_STAGE2)
	@dd \
		if=/dev/null \
		of=$(BOOT_IMAGE) \
		bs=$(BOOT_SECTOR_SIZE) \
		count=0 \
		seek=$(BOOT_SECTORS)
	@dd \
		if=$(BOOT_STAGE1) \
		of=$(BOOT_IMAGE) \
		bs=$(BOOT_SECTOR_SIZE) \
		count=1 \
		conv=notrunc
	@mformat -i $(BOOT_IMAGE) \
		-M $(BOOT_SECTOR_SIZE) \
		-v "BOOT" \
		-T $(BOOT_SECTORS) \
		-h $(BOOT_HEADS) \
		-s $(BOOT_SECTORS_TRACK) \
		-r $(BOOT_ROOT_ENTRIES) \
		-L $(BOOT_FAT) \
		-R $(BOOT_RESERVED) \
		-1 \
		-k
#	@mmd -i $(BOOT_IMAGE) ::boot
	@mcopy -i $(BOOT_IMAGE) $(BOOT_STAGE2) ::loader.bin

clean:
	@rm -f $(BOOT_STAGE1) $(BOOT_STAGE2)
	@rm -f $(BOOT_IMAGE)
	@rm -f $(OBJS) *.o */*.o */*/*.o
	@rm -f $(OBJS:.o=.d) *.d */*.d */*/*.d

install: $(ARCH)-image

install-headers: