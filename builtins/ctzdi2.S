; Hand-optimised __ctzdi2 for i8085.
; Returns the count of trailing zeros in a 64-bit value.
;
; Calling convention:
;   [SP+2..9] = x (i64, little-endian)
;   Returns i32 in BC:DE
;
; Algorithm: check low 4 bytes first. If any non-zero, push them
;   as an i32 arg and CALL __ctzsi2. Else check high 4 bytes,
;   CALL __ctzsi2 and add 32. All zero: return 64.

	.section .text.__ctzdi2, "ax", @progbits
	.globl	__ctzdi2
	.type	__ctzdi2,@function
__ctzdi2:
	; Check if low 4 bytes (SP+2..5) are all zero
	lxi	h, 2
	dad	sp
	mov	a, m		; byte 0
	inx	h
	ora	m		; | byte 1
	inx	h
	ora	m		; | byte 2
	inx	h
	ora	m		; | byte 3
	jz	.Lctzdi_high

	; Low 4 bytes non-zero: push them and call __ctzsi2
	; __ctzsi2 expects [SP+2..5] = x (i32)
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

	call	__ctzsi2

	; Clean up stack (4 bytes pushed)
	pop	h
	pop	h
	; Result already in BC:DE
	ret

.Lctzdi_high:
	; Low 4 bytes all zero, check high 4 bytes (SP+6..9)
	lxi	h, 6
	dad	sp
	mov	a, m		; byte 4
	inx	h
	ora	m		; | byte 5
	inx	h
	ora	m		; | byte 6
	inx	h
	ora	m		; | byte 7
	jz	.Lctzdi_allzero

	; High 4 bytes non-zero: push them and call __ctzsi2
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

	call	__ctzsi2

	; Clean up stack
	pop	h
	pop	h

	; Add 32 to the result in C (B is 0, DE is 0)
	mov	a, c
	adi	32
	mov	c, a
	ret

.Lctzdi_allzero:
	; All 8 bytes zero -> return 64
	mvi	c, 64
	mvi	b, 0
	mvi	e, 0
	mvi	d, 0
	ret

	.size	__ctzdi2, .-__ctzdi2
