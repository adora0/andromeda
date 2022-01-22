# Track source files for all objects
ARCH_SRC := \
	vga.S \
	disk.S \
	a20.S

# Bootstrap source files
# Boot stage loads the kernel loader
ARCH_BOOT_SRC := \
	boot/boot.S

# Kernel loader source files
ARCH_LOADER_SRC := \
	loader/loader.S

# Generate object paths (must include architecture directory path)
# Add source extensions to %.o filter
BOOT_OBJS := \
$(foreach obj, $(filter %.o, \
	$(ARCH_BOOT_SRC:.S=.o) \
), $(OBJDIR)/$(ARCHDIR)/$(obj))

LOADER_OBJS := \
$(foreach obj, $(filter %.o, \
	$(ARCH_LOADER_SRC:.S=.o) \
), $(OBJDIR)/$(ARCHDIR)/$(obj))

# Binaries
BOOT_BIN		:= $(OBJDIR)/$(ARCHDIR)/boot.bin
LOADER_BIN		:= $(OBJDIR)/$(ARCHDIR)/loader.bin

# Architecture-specific targets
ARCH_TARGETS 	:= $(BOOT)

# Image file paths (max. 11 bytes for FAT12)
# Referenced in assembly source
LOADER_PATH		:= loader.bin
KERNEL_PATH		:= kernel.elf

## Disk configuration
BOOT_FAT_ENTRY_SIZE	:= 32
BOOT_SECTOR_SIZE    := 512
BOOT_SECTORS        := 2880
BOOT_HEADS          := 2
BOOT_SECTORS_TRACK  := 18
BOOT_READ_SECTORS   := 14
BOOT_ROOT_ENTRIES   := $(shell echo \
    '( $(BOOT_READ_SECTORS) * $(BOOT_SECTOR_SIZE) / $(BOOT_FAT_ENTRY_SIZE) )' \
    | bc)
BOOT_FAT_SIZE       := 12
BOOT_RESERVED       := 1

# Build boot image
$(BOOT): $(KERNEL) $(BOOT_BIN) $(LOADER_BIN)
	@dd \
		if=/dev/null \
		of=$(BOOT) \
		bs=$(BOOT_SECTOR_SIZE) \
		count=0 \
		seek=$(BOOT_SECTORS)
	@dd \
		if=$(BOOT_BIN) \
		of=$(BOOT) \
		bs=$(BOOT_SECTOR_SIZE) \
		count=1 \
		conv=notrunc
	@mformat -i $(BOOT) \
		-M $(BOOT_SECTOR_SIZE) \
		-v "BOOT" \
		-T $(BOOT_SECTORS) \
		-h $(BOOT_HEADS) \
		-s $(BOOT_SECTORS_TRACK) \
		-r $(BOOT_ROOT_ENTRIES) \
		-L $(BOOT_FAT_SIZE) \
		-R $(BOOT_RESERVED) \
		-1 \
		-k
	@mcopy -i $(BOOT) $(LOADER_BIN) ::$(LOADER_PATH)
	@mcopy -i $(BOOT) $(KERNEL) ::$(KERNEL_PATH)

# Link bootstrap code
$(BOOT_BIN): $(BOOT_OBJS) $(ARCHDIR)/boot/linker.ld
	@echo "  LD		$(@F)"
	@$(LD) $(LDFLAGS) -T$(ARCHDIR)/boot/linker.ld -o $@ $(BOOT_OBJS)

# Link kernel loader
$(LOADER_BIN): $(LOADER_OBJS) $(ARCHDIR)/loader/linker.ld
	@echo "  LD		$(@F)"
	@$(LD) $(LDFLAGS) -T$(ARCHDIR)/loader/linker.ld -o $@ $(LOADER_OBJS)
