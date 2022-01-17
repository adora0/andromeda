	.code16

/*
* Read sectors from disk
*	in:	AX = LBA
*		CX = number of sectors
*		ES:DI -> buffer
*
*	out:	data at ES:DI
*		CF set on error after 3 retries
*		ES:DI updated to end of buffer
*/
disk_read:
	pusha
	mov	%cx, %si		// store number of sectors
	mov	$3, %cx			// set counter to remaining attempts

1:	push	%cx			// store counter
	push	%ax			// store LBA

	/*
	* LBA to CHS conversion
	*	track = LBA / (sectors per track * number of heads)
	*	head = (LBA / sectors per track) % sectors per track
	*	sector = (LBA / sectors per track) + 1
	*/
	xor	%dx, %dx		// prepare DX:AX for operation
	divw	bpb_sectors_track	// LBA / sectors per track
	inc	%dl			// adjust for sector 0
	mov	%dl, %cl		// CL = sector (quotient)

	xor	%dx, %dx		// prepare DX:AX for operation
	divw	bpb_head_count		// / sectors per track
	mov	%dl, %dh		// DH = head (quotient)

	mov	%al, %ch		// CH = track (remainder)

	clc				// clear carry flag

	/*
	* Int 0x13/AH=0x02: Disk - Read sectors into memory
	*	in:	AH = 0x02
	*		AL = number of sectors to read
	*		CH = lower eight bits of cylinder number
	*		CL = sector number
	*		DH = head number
	*		DL = drive number
	*		ES:BX -> data buffer
	*/
	mov	$0x0201, %ax		// read 1 sector
	movb	drive_number, %dl	// DL = drive number
	mov 	%di, %bx		// BX = offset

	int	$0x13

	jnc	2f			// prepare for next read if success

	xor	%ah, %ah		// reset disk on failure
	int	$0x13

	pop	%ax			// restore LBA
	pop	%cx			// restore counter
	loop	1b			// retry if attempts remaining

	jmp	3f			// fail

2:	/*
	* Increment buffer pointer by 1 sector
	*/
	movw	bpb_sector_size, %ax
	add	%di, %ax		// add sector size to offset
	shr	$4, %ax			// get effective segment (offset >> 4)
	mov	%es, %di
	add	%ax, %di		// add segment
	mov	%di, %es		// store in %es

	pop	%ax			// restore LBA
	pop	%cx			// restore counter

	dec	%si			// decrement remaining sectors
	jz	4f			// exit if complete

	xor	%di, %di		// reset buffer offset
	inc	%ax			// increment LBA
	jmp	1b			// read next sector

3:	stc				// set carry flag on failure

4:	popa
	ret

/*
* Read FAT12/16 root directory
*	in:	ES:DI -> buffer
*
*	out:	data at ES:DI
*               BX = first data sector
*		CF set on error
*/
load_root:
	/* Store size in cx */
	mov	$32, %ax		// root entry size
	mulw	bpb_root_entries	// * number of entries
	divw	bpb_sector_size		// / sector size
	mov	%ax, %cx		// number of sectors

	/*
	* Store location in ax
	* CHS = LBA when head = 0 and track = 0
	*/
	xor	%ax, %ax
	movb	bpb_fat_count, %al		// number of FATs
	mulw	bpb_sectors_fat			// * sectors per FAT
	addw	bpb_reserved_sectors, %ax	// + reserved sectors
	movw	%ax, %bx			// base of root directory
	addw	%cx, %bx			// + size
	
	/* Save registers */
	push	%es
	push 	%di

	/* Read root directory */
	clc
	call	disk_read		// read sectors

	/* Restore registers */
	pop	%di
	pop 	%es

	ret

/*
* Find file in FAT12/16 root directory
*	in:	DX:SI -> filename
*		ES:DI -> root directory
*
*	out:	BX = index of first cluster
*		CF set if not found
*/

find_file:
	/* Load size of root directory */
	movw	bpb_root_entries, %cx	// initialize counter

1:	/* Compare filenames */
	push	%ds		// save registers
	push	%es
	push 	%si
	push 	%di
	push	%cx
	
	mov	%dx, %ds	// filename segment
	
	mov	$11, %cx	// 11-byte filename length
rep	cmpsb			// compare each byte pair in DS:SI and ES:DI
	
	pop	%cx		// restore registers
	pop 	%di
	pop 	%si
	pop	%es
	pop	%ds
	
	je	2f		// continue if match
	add	$32, %di	// go to next entry if not matching
	loop	1b

	stc			// set carry flag if not found
	jmp 	3f

2:	/* Store index of first cluster */
	push	%ds		// save registers
	push	%si
	push	%di

	mov	%es, %ax
	mov	%ax, %ds
	add	$26, %di	// get cluster bytes 26-27 from entry
	mov	%di, %si
	lodsw			// read word from ds:si into ax
	
	pop	%di		// restore registers
	pop	%si
	pop	%ds

	mov	%ax, %bx	// BX = cluster

3:	ret

/*
* Load file allocation tables
*	in:	ES:DI -> buffer
*
*	out:	data in ES:DI
*		CF set on error
*/
load_fat:
	/* Calculate size of FAT and store in cx */
	movw	bpb_sectors_fat, %ax	// sectors per FAT
	mulb	bpb_fat_count		// * number of FATs
	mov	%ax, %cx

	/* Save location in ax */
	movw	bpb_reserved_sectors, %ax

	/* Save registers */
	push	%es
	push 	%di

	/* Read FAT into buffer */
	clc
	call	disk_read

	/* Restore registers */
	pop	%di
	pop 	%es

	ret

/*
* Read file clusters from FAT
*	in:	AX = index of first cluster
*		DX:SI -> FAT
*		ES:DI -> destination
*
*	out:	data at ES:DI	
*/
load_file:
	pusha

1:	push	%ax			// save cluster index

	/*
	* Calculate LBA of cluster in ax
	* LBA = (cluster - 2) * sectors per cluster + first data sector
	*/
	sub	$2, %ax				// cluster - 2
	xor	%ch, %ch
	movb	bpb_sectors_cluster, %cl
	mul	%cx				// * sectors per cluster
	addw	disk_data_sector, %ax		// + first data sector

	/*
	* Read cluster
	* AX = cluster LBA, CX = sectors per cluster, ES:DI -> destination
	*/
	call	disk_read
	jc	4f
	
	/*
	* Calculate next cluster;
	* Each 12-bit cluster is not 16-bit aligned,
	* so values must be adjusted to only read
	* a single cluster when copying a word.
	*
	* If even cluster, mask the top 4 bits belonging to the next cluster 
	* If odd cluster, shift the address down 4 bits to discard the bits used by the previous cluster
	*/

	pop	%ax			// restore current cluster
	mov	%ax, %cx		// copy index
	shr	$1, %cx			// divide by 2
	add	%cx, %ax		// add to AX for (3/2) of current index
	push	%ds			// save segment
	mov	%dx, %ds		// use segment of FAT

	/* Read cluster index from FAT */
	lodsw				// read word from DS:SI into AX
	
	pop	%ds			// restore segment
	test	$1, %al			// least significant bit
	jz	2f			// even cluster if not set

	/* Odd cluster */
	shr	$4, %ax			// get high twelve bits

2:	/* Even cluster */
	and	$0x0F, %ah		// get low twelve bits

3:	/* Check */
	cmp	$0x0FF0, %ax		// exit on signature at end of file
	jne	1b			// next cluster

4:	popa
	ret
