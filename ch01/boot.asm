; nasm boot.asm -o boot.bin
; dd if=boot.bin of=boot.img bs=512 conv=notrunc
org 07c00h

mov ax, cs   ;使 cs, ds, es 指向同一段内
mov ds, ax 
mov es, ax

call DispStr
jmp $       ; 死循环，不停的在此处跳转 '$'当前地址

DispStr:
    mov  ax, BootMessage
    mov  bp, ax   ; ES:BP = 字符串地址
    mov  cx, 16   ; 字符串长度
    mov  ax, 01301h ; AH = 13, AL = 01h 显示设置
    mov  bx, 000ch    ; 页号位0  黑底红字 BL = 0xc
    mov  dl, 0
    int  10h       ;显示中断信号
    ret             ; reutrn 

BootMessage:   db "Hello, OS world!" ;长度 16
times 510 -($-$$) db  0 ; 用0 填充剩余的空间 MBR 512字节
dw  0xaa55           ; 引导盘结束标志
