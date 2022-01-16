	/*
	* Boot sector
	* Loads and executes the kernel loader from disk
	*/
	
	.code16
	.section .text
	.global _start

	/*
	* No addresses after 1MiB +64KiB can be used before
	* the A20 gate is enabled in the kernel loader
	*/

	/* Offset address of >1KiB stack top before boot code */
	.set STACK_TOP,		0x7000

	/*
	* Offset address to load the root directory and FAT
	* Located after boot code at 0x7C00
	*/
	.set DATA_ADDR,		0x8000

	/*
	* Offset address to load the loader binary
	* Located after buffer (must have sufficient space for the root directory)
	*/
	.set LOAD_ADDR,		0x9000

_start:
	/*
	* E9 (..) 90 opcodes required by BIOS parameter block
	* jmp short, nop
	*/
	jmp	main
	nop

/*
* FAT12/16 BIOS parameter block (BPB)
* Parameters set by format tools
*/
	. = _start + 0x03
bpb_oem_id:				.space	8, 0	// OEM identifier (max. 8 bytes, space-padded)
bpb_sector_size:		.word	0		// bytes per sector
bpb_sectors_cluster:	.byte	0		// sectors per cluster
bpb_reserved_sectors:	.word	0		// reserved (boot sector only)
bpb_fat_count:			.byte	0		// number of file allocation tables (FATs)
bpb_root_entries:		.word	0		// number of root directory entries (must span sectors)
bpb_sector_count:		.word	0		// number of 16-bit locgical sectors
bpb_media_type:			.byte	0		// media descriptor
bpb_sectors_fat:		.word	0		// sectors per FAT
bpb_sectors_track:		.word	0		// sectors per track
bpb_head_count:			.word	0		// number of heads on storage media
bpb_hidden_sectors:		.long	0		// number of hidden sectors
bpb_large_sectors:		.long	0		// number of 32-bit sectors

/*
* FAT12/16 Extended Boot Record (EBPB)
*/
	. = _start + 0x024
ebpb:
ebpb_drive_num:			.byte	0		// BIOS drive number (int 0x13)
ebpb_nt_flags:			.byte	0		// Windows NT flags (reserved)
ebpb_volume_signature:	.byte	0		// volume signature (0x28 or 0x29)
ebpb_volume_serial:		.space	4, 0	// serial for volume tracking (32-bit hex)
ebpb_volume_label:		.space	11, 0	// volume label string (max. 11 bytes, space-padded)
ebpb_system_id:			.space	8, 0	// file system type representation (not used)


	. = _start + 0x03E

/*
* Disk geometry
*/
disk_track:			.byte	0
disk_head:			.byte	0
disk_sector:		.byte	0
disk_cluster:		.word	0
drive_number:		.byte	0
disk_data_sector:	.word	0

/*
* Entry point
*/
main:
	ljmp	$0, $1f		// reset code segment
1:	cld					// clear direction flag for string operations
	cli					// disable interrupts for setup
	
	/* Initialize stack */
	xor		%ax, %ax
	movw	%ax, %ss			// reset stack segment
	movw	$STACK_TOP, %sp		// set stack top
	
	sti		// restore interrupts

	movb	%dl, drive_number	// drive number set by BIOS
	
/*
* Read FAT12/16 root directory into buffer
*/
load_root:
	/* Store size in cx */
	mov		$32, %ax			// root entry size
	mulw	bpb_root_entries	// * number of entries
	divw	bpb_sector_size		// / sector size
	mov		%ax, %cx			// number of sectors

	/*
	* Store location in ax
	* CHS = LBA when head = 0 and track = 0
	*/
	xor		%ax, %ax
	movb	bpb_fat_count, %al			// number of FATs
	mulw	bpb_sectors_fat				// * sectors per FAT
	addw	bpb_reserved_sectors, %ax	// + reserved sectors
	movw	%ax, %bx					// base of root directory
	addw	%cx, %bx					// + size
	movw	%bx, disk_data_sector
	
	/* Read root directory */
	xor		%bx, %bx
	mov		%bx, %es			// clear segment
	mov		$DATA_ADDR, %bx		// set buffer offset
	call	disk_read			// read sectors
	jc		err_disk
	
/*
* Find kernel loader executable
*/
find_file:
	/* Load size and address of root directory */
	movw	bpb_root_entries, %cx	// initialize counter
	mov		$DATA_ADDR, %bx			// root directory start offset

1:	/* Compare filenames */
	push	%ds					// save ds
	xor		%dx, %dx
	mov		%dx, %ds			// clear ds
	mov		%dx, %es			// clear es
	push	%cx					// save counter
	mov		$11, %cx			// 11-byte filename length
	mov		$loader_name, %si	// loader string address
	mov		%bx, %di			// entry address
rep	cmpsb						// compare each byte pair in ds:si and es:di
	pop		%cx					// restore counter
	pop		%ds					// restore ds
	
	je		2f					// continue if name matches
	add		$32, %bx			// go to next entry if not matching
	loop	1b

	jmp		err_no_file

2:	/* Store index of first cluster */
	push	%ds						// save ds
	xor		%ax, %ax
	mov		%ax, %ds				// clear ds
	add		$26, %bx				// get cluster bytes 26-27 from entry
	mov		%bx, %si
	lodsw							// read word from ds:si into ax
	pop		%ds						// restore ds
	movw	%ax, disk_cluster		// save cluster

/*
* Load the FAT to find the required clusters
*/
load_fat:
	/* Calculate size of FAT and store in cx */
	movw	bpb_sectors_fat, %ax	// sectors per FAT
	mulb	bpb_fat_count			// * number of FATs
	mov		%ax, %cx

	/* Save location in ax */
	movw	bpb_reserved_sectors, %ax

	/* Read FAT into buffer */
	xor		%bx, %bx
	mov		%bx, %es			// clear es
	mov		$DATA_ADDR, %bx		// buffer address
	call	disk_read
	jc		err_disk
	
/*
* Read the clusters of the executable
*/
load_file:
	/* Set initial source and destination addresses */
	xor		%bx, %bx
	mov		%bx, %es			// clear es
	mov		$LOAD_ADDR, %bx		// set offset
	movw	disk_cluster, %ax	// get first cluster index
	
1:	
	/*
	* Calculate LBA of cluster in ax
	* LBA = (cluster - 2)* sectors per cluster + first data sector
	*/
	sub		$2, %ax					// cluster - 2
	xor		%ch, %ch
	movb	bpb_sectors_cluster, %cl
	mul		%cx						// * sectors per cluster
	addw	disk_data_sector, %ax	// + first data sector

	/*
	* Read cluster
	* AX = cluster LBA, CX = sectors per cluster, ES:BX -> load buffer
	*/
	call	disk_read
	jc		err_disk
	
	/*
	* Calculate next cluster;
	* Each 12-bit cluster is not 16-bit aligned,
	* so values must be adjusted to only get
	* a single cluster when copying a word.
	*
	* If even cluster, mask the top 4 bits belonging to the next cluster 
	* If odd cluster, shift the address down 4 bits to discard the bits used by the previous cluster
	*/

	movw	disk_cluster, %ax	// get current cluster
	mov		%ax, %cx			// copy current cluster
	shr		$1, %cx				// divide by 2
	add		%cx, %ax			// add to ax for (3/2) of current index
	add		$DATA_ADDR, %ax		// add FAT location to address
	mov		%ax, %si
	push	%ds					// save ds
	xor		%cx, %cx
	mov		%cx, %ds			// clear ds
	lodsw						// read word from ds:si into ax
	pop		%ds					// restore ds

	test	$1, %al				// least significant bit
	jz		2f					// even cluster if not set

	/* Odd cluster */
	shr		$4, %ax				// get high twelve bits

2:	/* Even cluster */
	and		$0x0F, %ah			// get low twelve bits

3:	/* Check */
	movw	%ax, disk_cluster	// save cluster
	cmp		$0x0FF0, %ax		// signature at end of file
	jne		1b					// otherwise next cluster

/*
* Execute the loader
*/
start_loader:
	ljmp	$(LOAD_ADDR >> 4), $0	// jump and update segment

/*
* Halt execution
*/
_end:
	cli
1:	hlt
	jmp 1b


/*
* Read sectors from disk
*	in:			AX = LBA
*				CX = number of sectors
*				ES:BX -> buffer
*	out:		data at ES:BX
*				CF set on error after 3 retries
*				ES:BX updated to end of buffer
*/
disk_read:
	pusha
	mov		%cx, %si		// number of sectors
	mov		$3, %cx			// set counter to remaining attempts

1:	xchg	%cx, %di		// save counter
	push	%ax				// save LBA

	/*
	* LBA to CHS conversion
	*	track = lba / (sectors per track * number of heads)
	*	head = (lba / sectors per track) % sectors per track
	*	sector = (lba / sectors per track) + 1
	*/
	xor		%dx, %dx			// prepare dx:ax for operation
	divw	bpb_sectors_track	// lba / sectors per track
	inc		%dl					// adjust for sector 0
	movb	%dl, disk_sector
	xor		%dx, %dx			// prepare dx:ax for operation
	divw	bpb_head_count		// / sectors per track
	movb	%dl, disk_head		// head = quotient
	movb	%al, disk_track		// track = remainder
	clc							// clear carry flag

	/*
	* Int 0x13/AH=0x02: Disk - Read sectors into memory
	* In:	AH = 0x02
	*	AL = number of sectors to read
	*	CH = lower eight bits of cylinder number
	*	CL = sector number
	*	DH = head number
	*	DL = drive number
	*	ES:BX -> data buffer
	*/
	mov		$0x0201, %ax		// read 1 sector
	movb	disk_track, %ch		// ch = track
	movb	disk_sector, %cl	// cl = sector
	movb	disk_head, %dh		// dh = head
	movb	drive_number, %dl	// dl = drive number

	int		$0x13

	jnc		2f			// prepare for next read if success

	xor		%ah, %ah	// reset disk
	int		$0x13

	pop		%ax			// restore LBA (keep stack frame)
	xchg	%cx, %di	// get counter
	loop	1b			// retry if attempts remaining

	jmp		3f			// fail

2:	/*
	* increment read pointer es: by 1 sector
	*/
	movw	bpb_sector_size, %ax
	add		%bx, %ax	// add sector size to offset
	shr		$4, %ax		// get effective segment (offset >> 4)
	mov		%es, %bx
	add		%ax, %bx	// add segment
	mov		%bx, %es	// store in %es

	pop		%ax			// restore LBA (keep stack frame)
	
	xchg	%cx, %di	// temporarily restore counter
	dec		%si			// decrement remaining sectors
	jz		4f			// exit if complete

	xor		%bx, %bx	// read es:0
	inc		%ax			// increment LBA
	jmp		1b			// read next sector

3:	stc					// set carry flag on failure

4:	popa				// restore registers, exit
	ret

/*
* Loader filename
* 11 chars with no null termination
*/
loader_name:		.ascii  "LOADER  BIN"

/*
* Error messages
*/
	.macro err str
	leaw	\str, %si
	call	puts
	jmp		_end
	.endm
err_disk:			err	msg_err_disk
err_no_file:		err	msg_err_no_file
msg_err_disk:		.asciz "Read error\n\r"
msg_err_no_file:	.asciz "Loader not found\n\r"

/*
* Includes
*/
	.include	"vga.S"

/*
* End of sector
*/
signature:
	. = _start + 0x1FE	// 512 bytes - signature length
	.word 0xAA55		// boot signature
