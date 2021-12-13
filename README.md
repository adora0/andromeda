# Cosmos

The Cosmos Operating System

## Overview

Cosmos is structured to be a Unix-like operating system with the following characteristics in mind:

- Monolithic/modular multitasking kernel
- C kernel codebase (C99)
- POSIX compliance and interoperability with other systems without compromising simplicity

## Hardware support

- i386 32-bit CPU *(IA-32 compatible, Intel i386 or newer)*
- IBM PC-compatible BIOS firmware

## Build Environment

### Prerequesites

- `sh`
- `make`
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

`$ ./tools/set_prefix.sh <PREFIX>`

Build the toolchain:

`$ ./tools/build_toolchain.sh`

### Building

`$ make`

`$ make image`

### Testing

*Requires `qemu-system-x86_64` or `qemu-system-i386`*

`$ make qemu`

## License

Released under the GPLv3 license. See `NOTICE` and `COPYING` for details.

## Documentation

Documentation is authored in English and refers to frequently used acronyms in hardware and software architecture and not all acronyms/abbreviations may be cited.

### Index

1. [Building](doc/build.md)
2. [Architecture](doc/architecture.md)
3. [Source Code](doc/source.md)
4. [External Reference for Development](doc/reference.md)