[bits 16]
[org 0x7C00]

    ; far jump, sets up cs=0x0000, ip=start
    jmp 0x0000:start

start:
    ; set Video Mode 13h
    mov ax, 0x0013
    int 0x10

    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00

    mov ax, 0x07E0
    mov ds, ax      ; set data segment *after* our 512 byte region

    ; initialize buffers (fill the 64kb zone after the MBR with 0s)
    mov es, ax      ; start of data segment
    xor di, di      ; index
    mov cx, 32768   ; counter
    xor ax, ax      ; 0x0000
    cld             ; clear direction flag so di is incremented
    rep stosw       ; write ax to es:di and increment di by 2 (word), cx times

    xor bp, bp      ; bp will be buffer A (current frame) at ds:0x0000
    mov di, 0x8000  ; di will be buffer B (next frame)    at ds:0x8000

    mov si, .seed_data
.seed_loop:
    mov bl, [cs:si]     ; get x
    mov bh, [cs:si+1]   ; get y
    cmp bx, 0xFFFF      ; end of seed_data
    je .seed_done

    ; this addressing trick works because as bh is incremented by 1,
    ; bx grows by 256 and each row in my array is 256 bytes long
    ; ex: x = 15, y = 4
    ; => bx = 0x040F = 4 * 16^2 + 15
    ;                = 4 * 256  + 15
    ; so [ds:bx] correctly selects the position in the buffer
    mov byte [ds:bx], 1
    add si, 2
    jmp .seed_loop

.seed_done:
    ; point es to the start of VGA memory
    ; A0000 -> AFFFF, 64kb available
    mov ax, 0xA000
    mov es, ax

.frame:
    ; store buffer B's location
    push di

    ; clear screen to blue
    xor di, di      ; start of video memory
    mov cx, 32000   ; 32k words
    mov ax, 0x0101  ; blue color index
    cld
    rep stosw

    ; restore buffer B
    pop di

    xor dx, dx      ; y
.y_loop:    
    xor cx, cx      ; x
.x_loop:
    xor si, si      ; neighbor count
    mov ah, -1      ; dy
.dy_loop:
    mov al, -1      ; dx
.dx_loop:
    mov bl, cl      ; bl = x
    add bl, al      ; bl = x + dx

    mov bh, dl      ; bh = y
    add bh, ah      ; bh = y + dy
    and bh, 127

    add bx, bp      ; start of buffer A
    mov bl, [ds:bx] ; get cell, same trick used previously while seeding
    xor bh, bh
    add si, bx

    inc al
    cmp al, 2
    jne .dx_loop
    inc ah
    cmp ah, 2
    jne .dy_loop

    ; get current cell's state
    mov bl, cl
    mov bh, dl
    add bx, bp
    mov al, [ds:bx]

    ; simplified simulation logic
    cmp si, 3
    je .alive
    cmp si, 4
    je .store
.dead:
    xor al, al
    jmp .store
.alive:
    mov al, 1
.store:
    mov bl, cl
    mov bh, dl
    add bx, di
    mov [ds:bx], al

    test al, al
    jz .next_x

    ; VGA resolution is 320x200, a frame's resolution is 256x128,
    ; so we need margins to display it centered.
    ; render white pixel:
    mov bx, dx
    add bx, 36      ; y + 36, vertical margin
    mov ax, bx
    shl bx, 8       ; * 256
    shl ax, 6       ; * 64
    add bx, ax      ; bx = (y + 36) * 320
    add bx, cx
    add bx, 32      ; x + 32, horizontal margin
    mov byte [es:bx], 0x000F

.next_x:
    inc cx
    cmp cx, 256
    jne .x_loop
    inc dx
    cmp dx, 128
    jne .y_loop

    xchg bp, di     ; swap buffer A and B

    call .wait_100ms

    jmp .frame

.wait_100ms:
    push ax
    push cx
    push dx
    mov ah, 0x86    ; BIOS Wait function
    mov cx, 0x0001  ; high 16 bits of 100,000
    mov dx, 0x86A0  ; low 16 bits of 100,000
    int 0x15
    pop dx
    pop cx
    pop ax
    ret

%ifndef SEED_FILE
    %define SEED_FILE "gun.inc"
%endif

%include SEED_FILE

times (510 - ($-$$)) db 0   ; padding
dw 0xAA55                   ; boot signature
