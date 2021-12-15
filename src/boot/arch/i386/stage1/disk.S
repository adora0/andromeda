	.code16

/*	function:	reset disk system
*	returns:	cf set on error after 3 retries
*/
disk_reset:
	pusha
	xorb	%cl, %cl		# reset counter
	movb	drive_read_num, %dl	# dl = drive
disk_reset__next:
	xorb	%ah, %ah		# ah = 00h (reset disk)
	int	$0x13

	jc	disk_reset__retry	# check retry on error
	jmp	disk_reset__exit
disk_reset__retry:
	cmpb	%cl, 3
	inc	%cl			# (inc. counter for next loop)
	jl	disk_reset__next	# retry if last counter < 3
disk_reset__exit:
	popa
	ret

/*	function:	read sectors from disk
*	parameters:	es:di = LBA
*			al = number of sectors
*	returns:	read_buffer = data
*			cf set on error after 3 retries
*/
disk_read:
	pusha
	xorb	%cl, %cl		# reset counter
	/* TODO: required parameters */
disk_read__next:
	movb	$0x02, %ah		# read sectors
	int	$0x13

	jc	disk_read__retry	# check retry on error
	jmp	disk_read__exit
disk_read__retry:
	cmpb	%cl, 3
	inc	%cl			# (inc. counter for next loop)
	jl	disk_read__next		# retry if last counter < 3
disk_read__exit:
	popa
	ret

/*	labels		*/
drive_read_num:		.byte 0		# floppy drive 0
drive_read_head:	.byte 0		# head 0
