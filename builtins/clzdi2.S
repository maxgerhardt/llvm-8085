; Hand-optimised __clzdi2 for i8085.
; Returns the count of leading zeros in a 64-bit value.
;
; Calling convention:
;   [SP+2..9] = x (i64, little-endian)
;   Returns i32 in BC:DE
;
; Algorithm: check high 4 bytes first (bytes 7..4). If any non-zero,
;   push them as an i32 arg and CALL __clzsi2. Else check low 4 bytes,
;   CALL __clzsi2 and add 32. All zero: return 64.

	.section .text.__clzdi2, "ax", @progbits
	.globl	__clzdi2
	.type	__clzdi2,@function
__clzdi2:
	; Check if high 4 bytes (SP+6..9) are all zero
	lxi	h, 6
	dad	sp
	mov	a, m		; byte 4
	inx	h
	ora	m		; | byte 5
	inx	h
	ora	m		; | byte 6
	inx	h
	ora	m		; | byte 7
	jz	.Lclzdi_low

	; High 4 bytes non-zero: push them and call __clzsi2
	; __clzsi2 expects [SP+2..5] = x (i32, little-endian)
	; bytes: SP+6=byte4(LSB of upper), SP+9=byte7(MSB)
	lxi	h, 9
	dad	sp
	mov	b, m		; byte 7
	dcx	h
	mov	c, m		; byte 6
	push	b		; push bytes 7,6
	dcx	h
	mov	b, m		; byte 5
	dcx	h
	mov	c, m		; byte 4
	push	b		; push bytes 5,4

	call	__clzsi2

	; Clean up stack (4 bytes pushed)
	pop	h
	pop	h
	; Result already in BC:DE
	ret

.Lclzdi_low:
	; High 4 bytes all zero, check low 4 bytes (SP+2..5)
	lxi	h, 2
	dad	sp
	mov	a, m		; byte 0
	inx	h
	ora	m		; | byte 1
	inx	h
	ora	m		; | byte 2
	inx	h
	ora	m		; | byte 3
	jz	.Lclzdi_allzero

	; Low 4 bytes non-zero: push them and call __clzsi2
	lxi	h, 5
	dad	sp
	mov	b, m		; byte 3
	dcx	h
	mov	c, m		; byte 2
	push	b		; push bytes 3,2
	dcx	h
	mov	b, m		; byte 1
	dcx	h
	mov	c, m		; byte 0
	push	b		; push bytes 1,0

	call	__clzsi2

	; Clean up stack
	pop	h
	pop	h

	; Add 32 to the result in C (B is 0, DE is 0)
	mov	a, c
	adi	32
	mov	c, a
	ret

.Lclzdi_allzero:
	; All 8 bytes zero -> return 64
	mvi	c, 64
	mvi	b, 0
	mvi	e, 0
	mvi	d, 0
	ret

	.size	__clzdi2, .-__clzdi2
