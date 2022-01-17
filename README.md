# AndromedaOS

A project to create a small, modular UNIX-like operating system including a kernel and minimal bootloader, using predominantly C and Assembly.

## Features

### CPU-based

Supported kernel architectures:

- [x] i386
- [ ] x86_64

Supported bootloader architectures:

- [x] i386 (BIOS)
- [ ] i386 (EFI)

### Components

- [-] Terminal implementation
    - [x] Basic kernel VGA output
    - [ ] VESA driver
    - [ ] Input handling
- [-] libc implementation
- [-] Bootloader
    - [x] FAT12 bootloader to execute loader executable
    - [ ] Kernel loader

## Build Prerequisites

- POSIX shell
- GNU make
- *(Optional)* Existing GNU binutils and GCC cross-compiler toolchains

OS-specific:

- Arch Linux
    - `base-devel`

Run with target architecture `TARGET` and cross-compiler toolchain prefix `PREFIX` if applicable:

`./configure.sh --target=TARGET --prefix=PREFIX`

*Note: `PREFIX` must be writable by the current user if the toolchain is not installed.*

If you do not have an existing toolchain installed for the target architecture, run:

`./tools/build_toolchain.sh`

## Building

Build bootable disk image (kernel, libraries and bootloader):

`make`

## Testing

Prerequisites:

- `qemu`

OS-specific:

- Arch Linux with non-x86_64 targets:
    - `qemu-arch-extra`

Boot the image in a virtual machine and build if not already built:

`make test`

## Debugging

Prerequisites:

- `gdb`
- *See [Testing](#Testing)*

Boot and debug the image in a virtual machine, and build if not already built:

`make debug`

## Source Code

Assembly source files are optimized for a tab width of 8 using hard tabs.

C source files are optimized for a tab width of 4 using spaces.

## License

GNU GPL version 3: see [`NOTICE`](NOTICE) and [`LICENSE`](LICENSE) for details.
