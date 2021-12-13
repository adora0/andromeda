# Cosmos

The Cosmos Operating System

## Overview

Cosmos is structured to be a Unix-like operating system with the following characteristics in mind:

- Free and open-source
- Monolithic/modular multitasking kernel
- C kernel codebase (C99)
- POSIX compliance and interoperability with other systems without compromising simplicity

The system is structured to comprise a basic kernel, bootloader and userspace command-line interface at its core, with the goal of writing the basis for a flexible operating system as a personal project in software architecture IA-32 programming.

## Hardware support

- Base
    - i386 32-bit CPU *(IA-32 compatible, Intel i386 or newer)*
    - IBM PC-compatible BIOS firmware
- Target
    - x86_64 64-bit CPU *(AMD64/Intel64 compatible, AMD Opteron / Intel Pentium 4 Prescott or newer)*
    - UEFI 2.0 compatible firmware

## Build Environment

### Prerequesites

- `sh`
- `grub`
    - `grub-file`
    - `grub-mkrescue`
- `libisoburn`
    - `xorriso`
    
- Toolchain (see [Building the Toolchain](###Building-the-Toolchain))
    - `<TARGET>-binutils`
        - `<TARGET>-ar`
        - `<TARGET>-as`
        - `<TARGET>-ld`
    - `<TARGET>-gcc`

Currently supported targets:

- `i386-elf`
- `i486-elf`
- `i586-elf`
- `i686-elf`

### Building the Toolchain

Requires:

- `curl`
- `tar`
- `gcc`

(Optional) Set the installation directory:

`$ ./scripts/set_prefix.sh <PREFIX>`

Build the toolchain:

`$ ./scripts/build_toolchain.sh`

### Building

`$ ./scripts/build_image.sh`

### Testing

*Requires `qemu-system-x86_64` or `qemu-system-i386`*

`$ ./scripts/qemu.sh`

## License

Released under the GPLv3 license. See `NOTICE` and `COPYING` for details.

## Documentation

Documentation is authored in English and refers to frequently used acronyms in hardware and software architecture and not all acronyms/abbreviations may be cited.

### Index

1. [Building](doc/build.md)
2. [Architecture](doc/architecture.md)
3. [Source Code](doc/source.md)
4. [External Reference for Development](doc/reference.md)