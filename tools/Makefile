BUILDDIR ?= build

SRC	:= \
	gdt.c

OUT := \
	$(foreach name, $(filter %, \
		$(SRC:.c=) \
	), $(BUILDDIR)/$(name))

.PHONY: all

all: $(OUT)

$(BUILDDIR)/%: %.c
	@mkdir -p $(@D)
	@echo "  CC		$(@F)"
	@$(CC) -MD $(CFLAGS) $(CPPFLAGS) -o $@ $<

clean:
	$(RM) $(OUT)

-include $(addsuffix .d, $(OUT))
