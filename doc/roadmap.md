# Development Roadmap

## Current

- Bootloader
	- ~~(Complete) Loaded by BIOS~~
	- ~~(Complete) Installed as boot sector into a formatted FAT12 disk~~
	- (-) Load second stage bootloader from disk to load 32-bit kernel

- Kernel
	- ~~(Complete) Loaded by multiboot compatible bootloader~~
	- ~~(Complete) Text mode 'Hello World'~~
	- ~~(Complete) Text mode scrolling~~
	- (-) Initial keyboard driver
	- (-) Program execution / basic memory management

## Future

- (-) libc Implementation

- (-) Userspace
    - (-) Shell
    - (-) Graphical User Interface