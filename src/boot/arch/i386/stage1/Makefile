include ./make.config

CPPFLAGS:=$(CPPFLAGS)
ASFLAGS:=$(ASFLAGS)
LDFLAGS:=$(LDFLAGS) --oformat=binary

OBJS=$(patsubst %, $(OBJDIR)/%.o, $(BOOT_STAGE1_SRC))

$(BOOT_STAGE1): $(OBJS) linker.ld
	@$(LD) $(LDFLAGS) -Tlinker.ld -o $@ $(OBJS)

$(OBJDIR)/%.S.o: %.S $(INCLUDES)
	@mkdir -p $(@D)
	@$(CPP) $(CPPFLAGS) -o $(OBJDIR)/$*.s $<
	@$(AS) $(ASFLAGS) -o $@ -c $(OBJDIR)/$*.s
	