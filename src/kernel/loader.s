/* multiboot v1 header constants */
.set MB_ALIGN,      1<<0                # align loaded modules on page boundaries
.set MB_MEMINFO,    1<<1                # memory map
.set MB_FLAGS,      MB_ALIGN | MB_MEMINFO     # 'flag' field
.set MB_MAGIC,      0x1BADB002          # kernel identifier for the bootloader
.set MB_CHECKSUM,   -(MB_MAGIC + MB_FLAGS)    # checksum

/*  multiboot v1 header
    marks the program as a kernel in the first 8KiB */
.section .multiboot
.align 4
.long MB_MAGIC
.long MB_FLAGS
.long MB_CHECKSUM

/*  allocate 16KiB stack
    16-byte aligned according to the System V ABI */
.section .bss
.align 16
stack_bottom:
.skip 16384
stack_top:

/*  kernel entry point
    loaded from 32-bit */
.section .text
.global _start
.type _start, @function
.extern kernel_main
_start:
    /* set stack top pointer */
    mov $stack_top, %esp
    /* enter kernel */
    call kernel_main
    /* TODO: initialize GDT and paging */
    /* disable interrupts and loop when finished */
    cli
1:  hlt
    jmp 1b

/* assign label size for debugging */
.size _start, . - _start
