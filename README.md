# AndromedOS

A project to create a modular UNIX-like operating system including a kernel and
minimal bootloader, written in C and Assembly.

## Features

### CPU

Supported kernel architectures:

- [x] i386
- [-] x86_64

Supported bootloader architectures:

- [x] i386 (BIOS)
- [ ] x86_64 (EFI)

### Components

- Kernel
    - [-] Terminal implementation
        - [x] VGA text output
        - [ ] VESA driver
        - [ ] Input handler
- [-] libc implementation
- Bootloader
    - [x] Boot sector to execute kernel loader
        - [x] FAT12
        - [ ] FAT16
        - [ ] FAT32
    - [-] Kernel loader

## Building

Shell commands to be run as user are denoted by `$`.

### Prerequisites

- POSIX shell
- GNU make
- `bc`
- `mtools`
- *(Optional)* Existing GNU binutils and GCC cross-compiler toolchain

### Prerequisites (OS-specific)

- Arch Linux
    - `bc` `base-devel` `mtools`

If you already have a toolchain installed for the target architecture, run:

`$ ./configure.sh --target=TARGET --prefix=PREFIX`

Otherwise if you do not already have a toolchain installed for the target
architecture, run:

`$ ./tools/install-toolchain.sh`

### Commands

Build a bootable disk image (kernel, libraries and bootloader):

`$ make`

## Testing

### Prerequisites

- QEMU

### Prerequisites (OS-specific)

- Arch Linux
    - `qemu-base` `qemu-ui-gtk` `qemu-system-TARGET`

### Commands

Build if not already built and boot the image in a virtual machine:

`$ make test`

*Disclaimer: As the bootloader is incomplete, build the components and run QEMU with
`build/kernel.elf` as the specified kernel to test the kernel only.*

## Debugging

### Prerequisites

- `gdb`
- *[Testing — Prerequisites](#prerequisites-1)*

### Commands

Build if not already built and debug the image in a virtual machine:

`$ make debug`

## Source Formatting

Assembly source files are optimized for a tab width of 8 using hard tabs.

C source files are optimized for a tab width of 4 using spaces.

## License

Released under the GNU GPLv3: see [`LICENSE`](LICENSE) for details.

Copyright (c) Kriss Wiggins 2022
