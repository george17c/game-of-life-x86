[bits 16]
[org 0x7C00]

	; far jump, sets up cs=0x0000, ip=start
	jmp 0x0000:start

start:
	; set Video Mode 13h (320x200 256 colors)
	mov ax, 0x0013
	int 0x10

	xor ax, ax
	mov ss, ax
	mov sp, 0x7C00

	mov ax, 0x07E0
	mov ds, ax
	mov es, ax

	; initialize buffers
	xor di, di
	mov cx, 0x8000
	xor ax, ax
	cld
	rep stosw

	; 256x128, 1 byte per cell
	xor bp, bp	; buffer A at ds:0x0000
	mov di, 0x8000	; buffer B at ds:0x8000

	mov si, seed_data
.seed_loop:
	mov bl, [cs:si]		; x
	mov bh, [cs:si+1]	; y
	cmp bx, 0xFFFF
	je .seed_done

	mov byte [bx], 1
	add si, 2
	jmp .seed_loop

.seed_done:
	; VGA memory A0000 -> AFFFF, 64kb available
	mov ax, 0xA000
	mov es, ax

frame:
	push di
	; clear screen to blue
	xor di, di	; start of video memory
	mov cx, 32000	; 32k words
	mov ax, 0x0101	; blue color index
	cld		; clear direction flag so di is incremented
	rep stosw	; write ax to es:di and increment di by 2 (word), cx times

	pop di

    	xor dx, dx	; y
.y_loop:	
	xor cx, cx	; x
.x_loop:
	xor si, si	; neighbor count
    	mov ah, -1	; dy
.dy_loop:
    	mov al, -1	; dx
.dx_loop:
	mov bl, cl	; bl = x
	add bl, al	; bl = x + dx

	mov bh, dl	; bh = y
	add bh, ah	; bh = y + dy
	and bh, 127

	add bx, bp

	mov bh, [bx]
	mov bl, bh
	xor bh, bh
	add si, bx

    	inc al
    	cmp al, 2
    	jne .dx_loop
    	inc ah
    	cmp ah, 2
    	jne .dy_loop

    	; get current cell's state
    	mov bx, dx
    	shl bx, 8
    	add bl, cl
    	add bx, bp
    	mov al, [bx]

    	; 9-cell rule evaluation
    	cmp si, 3
    	je .alive
    	cmp si, 4
    	je .store	; keeps current state
.dead:
    	xor al, al
    	jmp .store
.alive:
    	mov al, 1
.store:
	mov bx, dx		; write current state to next buffer
	shl bx, 8
	add bl, cl
	add bx, di
	mov [bx], al

	test al, al
	jz .next_x

	; render white pixel
	push di
	mov bx, dx
	add bx, 36         ; y + 36
	mov ax, bx
	shl bx, 8          ; * 256
	shl ax, 6          ; * 64
	add bx, ax         ; bx = y * 320
	add bx, cx
	add bx, 32	; x + 32
	mov byte [es:bx], 0x000F
	pop di

.next_x:
	inc cx
	cmp cx, 256
	jne .x_loop
	inc dx
	cmp dx, 128
	jne .y_loop

	xchg bp, di        ; Swap buffers

	call wait_sec

	jmp frame

wait_sec:
	push ax
	push cx
	push dx
	mov ah, 0x86	; BIOS Wait function
	mov cx, 0x0001	; high 16 bits of 100,000
	mov dx, 0x86A0	; low 16 bits of 100,000
	int 0x15
	pop dx
	pop cx
	pop ax
	ret

seed_data:
	db 1,4,2,4,1,5,2,5
	db 35,3,36,3,35,4,36,4
	db 13,2,14,2,12,3,16,3,11,4,17,4,11,5,15,5,17,5,18,5,11,6,17,6,12,7,16,7,13,8,14,8
	db 25,0,23,1,25,1,21,2,22,2,21,3,22,3,21,4,22,4,23,5,25,5,25,6
	db 200,80,201,80,202,80,200,81,202,81,200,82,202,82
	db 211,80,212,80,211,81,212,81
	
	db 124,58,125,58,126,58, 122,60,122,61,122,62, 124,63,125,63,126,63, 127,60,127,61,127,62
	db 130,58,131,58,132,58, 134,60,134,61,134,62, 130,63,131,63,132,63, 129,60,129,61,129,62
	db 124,65,125,65,126,65, 122,66,122,67,122,68, 124,70,125,70,126,70, 127,66,127,67,127,68
	db 130,65,131,65,132,65, 134,66,134,67,134,68, 130,70,131,70,132,70, 129,66,129,67,129,68
	dw 0xFFFF

times (510 - ($-$$)) db 0

dw 0xAA55	; boot signature
