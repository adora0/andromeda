# Cosmos

*Cosmos*: The Cosmos Operating System

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

## Build

### Prerequesites

See `tools/BUILDDEPS` for a newline-separated list of build dependencies. Package names are taken from the default Arch Linux package repositories and are primarily from the GNU utilities.

See `tools/OPTDEPS` for extra or post-build dependencies such as QEMU.

### Managing the Build Environment

The environment is configured by the `sysbuild` shell script.

To display its usage, use:

`$ ./sysbuild.sh --help`

### Setup

Prepare the build environment and build the toolchain:

`$ ./sysbuild.sh configure`

### Compilation

`$ make`

### Testing

*Requires `qemu-system-x86_64` or `qemu-system-i386`*

`$ ./sysbuild.sh run`

## License

Released under the GPLv3 license. See `NOTICE` and `COPYING` for details.

## Documentation

Documentation is currently authored in English and refers to frequently used acronyms in hardware and software architecture and not all acronyms/abbreviations may be cited.

### Index

1. [Building](doc/build.md)
2. [Architecture](doc/architecture.md)
3. [Source Code](doc/source.md)
4. [External Reference for Development](doc/reference.md)