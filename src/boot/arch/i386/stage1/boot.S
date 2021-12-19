#include <boot/config.h>

	.code16
	.section .text
	.global _start

	/* 16KiB+ stack top */
	.set STACK_TOP,		0x8000

	/* Segment to load the root directory and FAT clusters */
	.set BUFFER_ADDR,	0x9000

	/* Segment to load and execute the loader binary */
	.set LOAD_ADDR,		0xBF00

	/* Root entry size */
	.set ENTRY_SIZE,	32		# 32 bytes

	/* Filename size */
	.set FILENAME_LEN,	11		# 11 bytes

	/* Offset of cluster value in root entry */
	.set ENTRY_CLUSTER,	26		# byte 26 of entry

	/* FAT file end signature */
	.set FILE_END,		0x0FF0

/* 	Start execution (loaded at 0x7C00) 	*/
_start:
	/*	E9 (..) 90 opcodes required by FAT specification
	*	jmp short, nop
	*/
	jmp	main
	nop

/*	FAT12/16 BPB start (BIOS parameter block)
*	Parameters set by format tolls		*/
	. = _start + 0x03
bpb_oem_id:		.space	8, 0	# OEM identifier (max. 8 bytes, space-padded)
bpb_sector_size:	.word	0	# bytes per sector
bpb_sectors_cluster:	.byte	0	# sectors per cluster
bpb_reserved_sectors:	.word	0	# reserved (boot sector only)
bpb_fat_count:		.byte	0	# number of file allocation tables (FATs)
bpb_root_entries:	.word	0	# number of root directory entries (must span sectors)
bpb_sector_count:	.word	0	# number of 16-bit locgical sectors
bpb_media_type:		.byte	0	# media descriptor
bpb_sectors_fat:	.word	0	# sectors per FAT
bpb_sectors_track:	.word	0	# sectors per track
bpb_head_count:		.word	0	# number of heads on storage media
bpb_hidden_sectors:	.long	0	# number of hidden sectors
bpb_large_sectors:	.long	0	# number of 32-bit sectors

/*	FAT12/16 EBPB (Extended Boot Record) 	*/
	. = _start + 0x024
ebpb:
ebpb_drive_num:		.byte	0	# BIOS drive number (int 0x13)
ebpb_nt_flags:		.byte	0	# Windows NT flags (reserved)
ebpb_volume_signature:	.byte	0	# volume signature (0x28 or 0x29)
ebpb_volume_serial:	.space	4, 0	# serial for volume tracking (32-bit hex)
ebpb_volume_label:	.space	11, 0	# volume label string (max. 11 bytes, space-padded)
ebpb_system_id:		.space	8, 0	# file system type representation (not used)


/*	Boot code	*/
	. = _start + 0x03E
main:
	ljmp	$0, $1f		# reset code segment
1:	cld			# clear direction flag for string operations
	cli			# disable interrupts for setup
	
	/* Initialize stack */
	xor	%ax, %ax
	movw	%ax, %ss	# reset stack segment
	movw	$STACK_TOP, %sp	# set stack top

	sti			# restore interrupts
	
/* Reset disk system */
disk_reset:
	movb	disk_drive, %dl	# dl = drive number
	movb	$3, %cl		# set counter
1:	clc
	xorb	%ah, %ah	# ah = 0 (reset disk)
	int	$0x13
	jc	2f		# check retry on error
	jmp	load_root	# exit on success
2:
	loop	1b		# retry if last counter > 0
	jc	err_disk
	
/* Read FAT12/16 root directory into buffer */
load_root:
	/* store size in cx */
	xor	%cx, %cx
	xor	%dx, %dx
	movw	$ENTRY_SIZE, %ax	# root entry size
	mulw	bpb_root_entries	# * number of entries
	divw	bpb_sector_size		# / sector size
	mov	%ax, %cx		# number of sectors

	/* store location in ax;
	 * CHS = LBA when head = 0 and track = 0
	 */
	xor	%ax, %ax
	movb	bpb_fat_count, %al		# number of FATs
	mulw	bpb_sectors_fat			# * sectors per FAT
	addw	bpb_reserved_sectors, %ax	# + reserved sectors
	movw	%ax, disk_root_sector
	
	/* read root directory */
	movw	$BUFFER_ADDR, %bx	# set buffer offset
	push	%es
	call	disk_read		# read sectors
	pop	%es			# restore modified segment
	jc	err_disk
	
/* Find loader binary */
find_loader:
	/* load size and address of root directory */
	movw	bpb_root_entries, %cx	# initialize counter
	movw	$BUFFER_ADDR, %bx	# root directory start offset
	xor	%dx, %dx
	movw	%dx, %es		# clear root directory segment

1:	/* compare filenames */
	push	%cx			# save counter
	movw	$FILENAME_LEN, %cx
	movw	$loader_name, %si	# loader string
	movw	%bx, %di		# entry string
rep	cmpsb				# compare each byte pair in ds:si and es:di
	pop	%cx			# restore counter
	je	load_fat		# load FAT if name matches
	addw	$ENTRY_SIZE, %bx	# go to next entry if not matching
	loop	1b

	jmp	err_no_file

	/* store address of first cluster */
	movw	%di, %dx		# get entry address
	addw	$ENTRY_CLUSTER, %dx	# get cluster bits from entry
	movw	%dx, disk_cluster

/* Load the FAT to find the required clusters */
load_fat:
	/* get number of sectors used by FATs */
	xor	%ax, %ax
	movb	bpb_fat_count, %al	# number of fats
	mulw	bpb_sectors_fat		# * sectors per FAT
	mov	%ax, %cx		# store size in cx

	/* store location of first FAT in ax */
	movw	bpb_reserved_sectors, %ax

	/* load FAT */
	movw	$BUFFER_ADDR, %bx	# set buffer offset
	push	%es
	call	disk_read		# read sectors
	pop	%es			# restore modified segment
	jc	err_disk

/* Read the clusters of the binary
 * MARK: needs updating, the loader is not yet properly loaded */
load_clusters:
	/* load initial buffer address */
	movw	$LOAD_ADDR, %bx
	mov	%bx, %es		# set segment	
	xor	%bx, %bx		# clear offset

	/* load initial cluster address */
	movw	disk_cluster, %ax

1:	/* cluster stored in ax;
	 * LBA = (cluster - 2) * sectors per cluster
	 */
	sub	$2, %ax
	xor	%cx, %cx
	movb	bpb_sectors_cluster, %cl
	mulw	%cx
	addw	disk_root_sector, %ax

	push	%es
	call	disk_read		# read sectors
	pop	%es			# restore modified segment
	jc	err_disk

	/* Calculate next cluster;
	 * Each 12-bit cluster is not 16-bit aligned,
	 * so we must adjust the values to copy only
	 * a single cluster when copying a word.
	 *
	 * Algorithm:
	 *	If even cluster, mask out the top 4 bits belonging to the next cluster 
	 *	If odd cluster, shift the address down 4 bits to discard the bits used by the first byte
	 */
	movw	disk_cluster, %ax	# current cluster
	mov	%ax, %cx		# copy
	mov	%ax, %dx		# copy
	shr	$1, %dx			# divide by 2
	add	%dx, %cx		# cx = (3/2) * cluster

	movw	$BUFFER_ADDR, %bx	# location of loaded FAT
	add	%bx, %cx		# index into FAT
	mov	%bx, %si
	lodsw				# read word from ds:si into ax

	/* odd if division by 2 set the carry flag */
	jc	cluster_odd
cluster_even:
	/* even cluster */
	andb	$0x0F, %ah	# get low 12 bits
	jmp	2f
cluster_odd:
	/* odd cluster */
	shr	$4, %ax		# get high 12 bits

2:	/* finished processing cluster */
	cmpw	$FILE_END, %ax
	je	start_loader	# exit on file end signature
	jmp	1b		# read next cluster

/* Execute the loader binary */
start_loader:
	ljmp	$(LOAD_ADDR >> 4), $0	# update segment to load address


/* Halt execution */
_end:
	cli
1:	hlt
	jmp 1b


/*	Functions	*/

/* Output a null-terminated string in text mode
*	Parameters:	SI -> string
*/
puts:
	pusha
1:	lodsb			# load character from %si into %al
	or	%al, %al
	jz	2f		# exit on null byte

	movb	$0x0E, %ah	# teletype output
	xor	%bx, %bx	# bh = 0 (page number), bl = 0 (foreground color)
	int	$0x10
	jmp	1b		# next

2:	popa
	ret

/* Read sectors from disk
*	Parameters:	AX = LBA
*			CX = number of sectors
*			ES:BX => buffer
*	Returns:	data at ES:BX
*			CF set on error after 3 retries
*			ES buffer segment updated to end pointer
*/
disk_read:
	pusha
	movw	%cx, %si		# si = number of sectors
	movw	$3, %cx			# counter = 3

1:	xchg	%cx, %di		# save counter
	push	%ax			# save LBA

	/* LBA to CHS conversion
	*	track = lba / (sectors per track * number of heads)
	*	head = (lba / sectors per track) % sectors per track
	*	sector = (lba / sectors per track) + 1
	*/
	xor	%dx, %dx		# prepare dx:ax for operation
	divw	bpb_sectors_track	# calculate
	inc	%dl			# adjust for sector 0
	movb	%dl, disk_sector
	xor	%dx, %dx		# prepare dx:ax for operation
	divw	bpb_head_count		# calculate
	movb	%dl, disk_head		# head = quotient
	movb	%al, disk_track		# track = remainder
	clc				# clear carry flag

	/* Int 0x13/AH=0x02: Disk - Read sectors into memory
	* In:	AH = 0x02
	*	AL = number of sectors to read
	*	CH = lower eight bits of cylinder number
	*	CL = sector number
	*	DH = head number
	*	DL = drive number
	*	ES:BX -> data buffer
	*/
	movw	$0x0201, %ax		# read 1 sector
	movb	disk_track, %ch		# ch = track
	movb	disk_sector, %cl	# cl = sector
	movb	disk_head, %dh		# dh = head
	movb	disk_drive, %dl		# dl = drive number

	int	$0x13

	jnc	2f			# prepare for next read if success

	xorb	%ah, %ah		# reset disk
	int	$0x13

	pop	%ax			# restore LBA (keep stack frame)
	xchg	%cx, %di		# get counter
	loop	1b			# retry if attempts remaining

	jmp	3f			# fail

2:	/* increment read pointer es: by 1 sector */
	movw	bpb_sector_size, %ax
	add	%bx, %ax		# add sector size to offset
	shr	$4, %ax			# get effective segment (offset >> 4)
	mov	%es, %bx
	add	%ax, %bx		# add segment
	movw	%bx, %es		# store in es:

	pop	%ax			# restore LBA (keep stack frame)
	
	xchg	%cx, %di		# temporarily restore counter
	decw	%si			# decrement remaining sectors
	jz	4f			# exit if complete

	xor	%bx, %bx		# read es:0
	inc	%ax			# increment LBA
	jmp	1b			# read next sector

3:	stc				# set carry flag on failure

4:	popa				# restore registers, exit
	ret


/*	Error calls		*/
	.macro err str
	leaw	\str, %si
	call	puts
	jmp	_end
	.endm
err_disk:		err	msg_err_disk
err_no_file:		err	msg_err_no_file

/*	Symbols			*/
msg_err_disk:		.asciz 	"Read error\n\r"
msg_err_no_file:	.asciz	"Loader not found\n\r"

/* Loader binary filename
 * 11 chars, no null termination for comparison
 */
loader_name:		.ascii	"LOADER  BIN"

/*	Disk parameters		*/
disk_track:		.byte	0
disk_head:		.byte	0
disk_sector:		.byte	0
disk_drive:		.byte	0	# primary floppy drive
disk_cluster:		.word	0
disk_root_sector:	.word	0	# start of root directory

/*	Sector end		*/
signature:
	. = _start + 0x1FE	# 512 bytes - signature length
	.word 0xAA55		# boot signature
