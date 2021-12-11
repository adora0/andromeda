include .env
ifdef builddir

srcdir	:= ./src
libdir	:= ./lib
incdir	:= ./include

# source files
boot_srcdir 	:= 	$(srcdir)/boot
boot_ld 		:= 	$(boot_srcdir)/link.ld
kernel_srcdir	:= 	$(srcdir)/kernel
kernel_ld 		:= 	$(kernel_srcdir)/link.ld

boot_src_as		:=	$(wildcard $(boot_srcdir)/*.s)
kernel_src_cc	:=	$(wildcard $(kernel_srcdir)/*.c)
kernel_src_as	:=	$(wildcard $(kernel_srcdir)/*.s)
lib_src_cc		:=	$(wildcard $(libdir)/*.c)

# output
boot_objdir		:= 	$(builddir)/boot
kernel_objdir	:= 	$(builddir)/kernel
lib_objdir		:= 	$(builddir)/lib
builddirs		:= 	$(builddir) $(boot_objdir) $(kernel_objdir) $(lib_objdir)

boot_obj		:=	$(boot_src_as:$(boot_srcdir)/%.s=$(boot_objdir)/%.o)
kernel_obj		:=	$(kernel_src_cc:$(kernel_srcdir)/%.c=$(kernel_objdir)/%.o) \
					$(kernel_src_as:$(kernel_srcdir)/%.s=$(kernel_objdir)/%.o)
lib_obj			:=	$(lib_src_cc:$(libdir)/%.c=$(lib_objdir)/%.o)

boot_bin		:=	$(builddir)/boot.bin
kernel_bin		:=	$(builddir)/kernel.bin

# compiler flags
ASFLAGS			+= 	--warn
LDFLAGS_BOOT 	:= 	$(LDFLAGS) -T$(boot_ld) --oformat=binary
CFLAGS			+= 	-std=gnu99 -ffreestanding -O2 -nostdlib -Wall -Wextra -lgcc -I$(incdir) -c
CFLAGS_LINK 	:= 	-T$(kernel_ld) -ffreestanding -O2 -nostdlib -lgcc

# messages
MSG_AS			= 	** (AS) $^
MSG_CC 			= 	** (CC) $^
MSG_LD 			= 	** (LD) $^
MSG_CC_LINK 	= 	** (CC) [link] $^

# executables configured in environment file
PATH 		:=	$(PATH):$(prefix)/bin
AS		= 	echo "$(MSG_AS)"; $(target)-as
CC		= 	echo "$(MSG_CC)"; $(target)-gcc
LD 		= 	echo "$(MSG_LD)"; $(target)-ld
CC_LINK	= 	echo "$(MSG_CC_LINK)"; $(target)-gcc

.SILENT:
all : init $(boot_bin) $(kernel_bin)

init:
	@mkdir -p $(builddirs)

clean:
	@rm -rf $(builddirs)

# bootloader
$(boot_bin) : $(boot_obj)
	$(LD) -o $@ $(LDFLAGS_BOOT) $^

$(boot_objdir)/%.o : $(boot_srcdir)/%.s
	$(AS) -o $@ $(ASFLAGS) $^

# kernel
$(kernel_bin) : $(kernel_obj) $(lib_obj)
	$(CC_LINK) -o $@ $(CFLAGS_LINK) $^

$(kernel_objdir)/%.o : $(kernel_srcdir)/%.c
	$(CC) -o $@ $(CFLAGS) $^

$(kernel_objdir)/%.o : $(kernel_srcdir)/%.s
	$(AS) -o $@ $(ASFLAGS) $^

# libraries
$(lib_objdir)/%.o : $(libdir)/%.c
	$(CC) -o $@ $(CFLAGS) $^

endif