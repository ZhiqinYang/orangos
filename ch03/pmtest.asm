;编译方法 ： nasm -pmtest.asm -o pmtest.bin

;描述符结构图
; 图示一
;
;  ------ ┏━━┳━━┓高地址
;         ┃ 7  ┃ 段 ┃
;         ┣━━┫    ┃
;                  基
;  字节 7 ┆    ┆    ┆
;                  址
;         ┣━━┫ ② ┃
;         ┃ 0  ┃    ┃
;  ------ ┣━━╋━━┫
;         ┃ 7  ┃ G  ┃
;         ┣━━╉──┨
;         ┃ 6  ┃ D  ┃
;         ┣━━╉──┨
;         ┃ 5  ┃ 0  ┃
;         ┣━━╉──┨
;         ┃ 4  ┃ AVL┃
;  字节 6 ┣━━╉──┨
;         ┃ 3  ┃    ┃
;         ┣━━┫ 段 ┃
;         ┃ 2  ┃ 界 ┃
;         ┣━━┫ 限 ┃
;         ┃ 1  ┃    ┃
;         ┣━━┫ ② ┃
;         ┃ 0  ┃    ┃
;  ------ ┣━━╋━━┫
;         ┃ 7  ┃ P  ┃
;         ┣━━╉──┨
;         ┃ 6  ┃    ┃
;         ┣━━┫ DPL┃
;         ┃ 5  ┃    ┃
;         ┣━━╉──┨
;         ┃ 4  ┃ S  ┃
;  字节 5 ┣━━╉──┨
;         ┃ 3  ┃    ┃
;         ┣━━┫ T  ┃
;         ┃ 2  ┃ Y  ┃
;         ┣━━┫ P  ┃
;         ┃ 1  ┃ E  ┃
;         ┣━━┫    ┃
;         ┃ 0  ┃    ┃
;  ------ ┣━━╋━━┫
;         ┃ 23 ┃    ┃
;         ┣━━┫    ┃
;         ┃ 22 ┃    ┃
;         ┣━━┫ 段 ┃
;
;   字节  ┆    ┆ 基 ┆
; 2, 3, 4
;         ┣━━┫ 址 ┃
;         ┃ 1  ┃ ① ┃
;         ┣━━┫    ┃
;         ┃ 0  ┃    ┃
;  ------ ┣━━╋━━┫
;         ┃ 15 ┃    ┃
;         ┣━━┫    ┃
;         ┃ 14 ┃    ┃
;         ┣━━┫ 段 ┃
;
; 字节 0,1┆    ┆ 界 ┆
;
;         ┣━━┫ 限 ┃
;         ┃ 1  ┃ ① ┃
;         ┣━━┫    ┃
;         ┃ 0  ┃    ┃
;  ------ ┗━━┻━━┛低地址
;

%include "pm.inc"   ; 常量和一些数据结构的定义
org 07c00h
    jmp LABEL_BEGIN

[SECTION .gdt]
;GDT BEGAIN
;                      段基址（段首地址）  ，  断界限（段长度） ，   属性
LABEL_GDT:  Descriptor 0 ,      0,      0 ;空描述符
LABEL_DESC_CODE32: Descriptor  0,    SegCode32Len -1 , DA_C + DA_32 ;非一致代码段
LABEL_DESC_VIDEO:  Descriptor  0B8000h,   0ffffh, DA_DRW ;显存首地址
;GDT END

GdtLen equ $ - LABEL_GDT
GdtPr  dw  GdtLen - 1 
       dd  0

;GDT SELECTOR   选择子（在这里等价于偏移量）
SelectorCode32  equ LABEL_DESC_CODE32 - LABEL_GDT
SelectorVideo   equ LABEL_DESC_VIDEO - LABEL_GDT

;END  of [SECTTION .gtd]


[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
    mov  ax, cs
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0100h

    ;初始化32位代码段描述符，主要是段基地址的转换 16 =》 32 位 
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32              ; 计算物理地址（16 位转32位）= 段地址 + 偏移 
    mov word [LABEL_DESC_CODE32 + 2] , ax  ;段界限占2个字节，所以偏移两个字节，初始化段基地址 (1)   |
    shr eax , 16                                                                                    ||} 共三个字节
    mov byte [LABEL_DESC_CODE32 + 4] , al  ;断界限（1）占三个字节， 所以偏移位4，初始化段基地址 (1) |
    mov byte [LABEL_DESC_CODE32 + 7] , ah  ;初始化段基地址 (2) 一个字节

    ;加载GDTR 做准备 数据段16 = 》32
    xor  eax, eax
    mov  ax, ds
    shl  eax, 4
    add eax, LABEL_GDT               ; 计算jdt线性地址
    mov  dword [GdtPr + 2] , eax     ; 将jdt线性地址保存到 0 -1 号地址中 

    lgdt [GdtPr]                     ; 加载gdt  GdtPr中记录了jdt长度和首地址 （加载数据）

    ;关闭中断
    ;cli 指令简介：
    ; CLI(clear interrupt)是将处理器标志寄存器的中断标志位清0，不允许中断,防止硬件干扰。
    ; CLI经常与STI(set interrupt)成对使用，STI的是将处理器标志寄存器的中断标志置1，允许中断。
    cli   


    ; A20 地址线简介：
    ;
    ;有些操作系统将A20 的开启和禁止作为实模式与保护运行模式之间进行转换的标准过程中的一部分。
    ;由于键盘的控制器速度很慢，因此就不能使用键盘控制器对A20 线来进行操作。为此引进了一个A20 
    ;快速门选项(Fast Gate A20)，它使用I/O 端口0x92 来处理A20 信号线，避免了使用慢速的键盘控制
    ;器操作方式。对于不含键盘控制器的系统就只能使用0x92 端口来控制，但是该端口也有可能被其它兼
    ;容微机上的设备（如显示芯片）所使用，从而造成系统错误的操作。还有一种方式是通过读0xee 端口
    ;来开启A20 信号线，写该端口则会禁止A20 信号线。开A20地址线     ; 要使cpu工作在32位模式下必
    
    ;须打开A20地址线，目的向上兼容（有溢出）
    in al, 92h         ;从91h 端口读入一个字节到al中
    or al, 00000010b   ; 将al 中的第二位置 1
    out 92h, al        ; al中的内容写会al     

    ;准备切换到保护模式
    mov eax, cr0
    or eax, 1
    mov cr0 , eax

    ;进入保护模式
    jmp  dword SelectorCode32:0     ; 跳转的关键 dword  32位 防止偏移大的截断

;END of [SECTTION .s166]

[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:
    mov ax, SelectorVideo
    mov gs, ax

    mov edi , (80 * 11 + 2 )*2 ; 屏幕 11行 79列
    mov ah, 0ch
    mov al, 'p'
    mov [gs:edi] , ax
    ;停止  
    jmp $
SegCode32Len equ $ - LABEL_SEG_CODE32
;END of [SECTTION .s32]
Message: db "Hello Os"
      times 510 - ($ - $$)   db 0
      dw 0xaa55
