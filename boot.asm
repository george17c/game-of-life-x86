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
    mov ds, ax  ; set data segment *after* our 512 byte region
                ; since nothing's there and we need space for
                ; double buffering

    ; initialize buffers
    mov es, ax      ; start of data segment
    xor di, di      ; index in buffer memory
    mov cx, 32768   ; both buffers are 32768 words (or 65536 bytes) long in total 
    xor ax, ax      ; 0x0000
    cld             ; clear direction flag so di is incremented
    rep stosw       ; write ax to es:di and increment di by 2 (word), cx times

    ; 256x128 arrays, 1 byte per cell
    xor bp, bp        ; bp will be buffer A at ds:0x0000
    mov di, 0x8000    ; di will be buffer B at ds:0x8000

    mov si, .seed_data
.seed_loop:
    mov bl, [cs:si]     ; get x
    mov bh, [cs:si+1]   ; get y
    cmp bx, 0xFFFF      ; end of seed_data
    je .seed_done

    ; this trick works because as bh is incremented by 1, bx grows by 256
    ; and each row in my array is 256 bytes long
    ; ex: x = 15, y = 4
    ; => bx = 0x040F = 4 * 16^2 + 15
    ;          = 4 * 256  + 15
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

    ; 9-cell rule evaluation
    cmp si, 3
    je .alive
    cmp si, 4
    je .store    ; keeps current state
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

    ; render white pixel
    push di
    mov bx, dx
    add bx, 36      ; y + 36, vertical margin
    mov ax, bx
    shl bx, 8       ; * 256
    shl ax, 6       ; * 64
    add bx, ax      ; bx = (y + 36) * 320
    add bx, cx
    add bx, 32      ; x + 32, horizontal margin
    mov byte [es:bx], 0x000F
    pop di

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

.seed_data:
    ; Gosper's glider gun
    db 1,4,2,4,1,5,2,5
    db 35,3,36,3,35,4,36,4
    db 13,2,14,2,12,3,16,3,11,4,17,4,11,5,15,5,17,5,18,5,11,6,17,6,12,7,16,7,13,8,14,8
    db 25,0,23,1,25,1,21,2,22,2,21,3,22,3,21,4,22,4,23,5,25,5,25,6

    ; piheptomino2integral
    db 200,80,201,80,202,80,200,81,202,81,200,82,202,82
    db 211,80,212,80,211,81,212,81

    ; infinite growth
    db 51,64,52,64,53,64,54,64,55,64,56,64,57,64,58,64, 60,64,61,64,62,64,63,64,64,64
    db 68,64,69,64,70,64, 77,64,78,64,79,64,80,64,81,64,82,64,83,64
    db 85,64,86,64,87,64,88,64,89,64

    ; penta-decathlon
    db 190,30,191,30, 192,31,192,29, 193,30,194,30,195,30,196,30, 197,31,197,29, 198,30,199,30

    ; pulsar
    db 124,38,125,38,126,38, 122,40,122,41,122,42, 124,43,125,43,126,43, 127,40,127,41,127,42
    db 130,38,131,38,132,38, 134,40,134,41,134,42, 130,43,131,43,132,43, 129,40,129,41,129,42
    db 124,45,125,45,126,45, 122,46,122,47,122,48, 124,50,125,50,126,50, 127,46,127,47,127,48
    db 130,45,131,45,132,45, 134,46,134,47,134,48, 130,50,131,50,132,50, 129,46,129,47,129,48

    ; end bytes
    dw 0xFFFF

times (510 - ($-$$)) db 0   ; padding
dw 0xAA55                   ; boot signature
