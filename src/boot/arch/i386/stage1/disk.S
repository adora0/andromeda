	.code16

	.extern bpb_sectors_track
	.extern bpb_head_count
	.extern bpb_sector_size

	.global disk_reset
	.global disk_read

/*	Reset disk system
*	Parameters:	DL = drive number
*	Returns:	CF set on error after 3 retries
*/
disk_reset:
	xorb	%cl, %cl		# reset counter
disk_reset__next:
	clc
	xorb	%ah, %ah		# ah = 0 (reset disk)
	int	$0x13

	jc	disk_reset__retry	# check retry on error
	jmp	disk_reset__exit
disk_reset__retry:
	cmpb	$3, %cl
	inc	%cl			# (inc. counter for next loop)
	jl	disk_reset__next	# retry if last counter < 3
	stc
disk_reset__exit:
	ret

/*	Read sectors from disk
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
	mov	$3, %di			# counter = 3
disk_read__next:
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
	mov	$0x0201, %ax		# read 1 sector
	movb	disk_track, %ch		# ch = lower 8 bits of cylinder number
	movb	disk_sector, %cl	# cl = sector number
	movb	disk_head, %dh		# dh = head number
	movb	disk_drive, %dl		# dl = drive number

	int	$0x13
	jnc	disk_read__ok		# read next sector if carry not set

	xor	%ax, %ax		# reset disk
	int	$0x13

	pop	%ax			# restore LBA (keep stack frame)
	dec	%di			# decrement counter
	jge	disk_read__next		# retry if attempts remaining

	stc				# set carry flag on final failure
	jmp	disk_read__exit		# exit
disk_read__ok:
	/* increment read pointer es: by 1 sector */
	movw	bpb_sector_size, %ax
	add	%bx, %ax		# add sector size to start offset
	shr	$4, %ax			# get effective segment (offset >> 4)
	mov	%es, %bx
	add	%ax, %bx		# add segment
	movw	%bx, %es		# store in es:

	pop	%ax			# restore LBA (keep stack frame)

	dec	%si			# decrement remaining sectors
	jz	disk_read__exit		# exit if complete

	inc	%ax			# increment LBA
	jmp	disk_read__next		# read next sector
disk_read__exit:
	popa
	ret


/*	Symbols		*/

disk_track:		.byte 0
disk_head:		.byte 0
disk_sector:		.byte 0
disk_drive:		.byte 0
