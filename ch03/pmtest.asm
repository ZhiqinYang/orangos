;编译方法 ： nasm -pmtest.asm -o pmtest.bin

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

    ;初始化32位代码段描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32              ; 计算物理地址（16 位转32位）= 段地址 + 偏移 
    mov word [LABEL_DESC_CODE32 + 2] , ax  ;初始化段基地址
    shr eax , 16
    mov byte [LABEL_DESC_CODE32 + 4] , al  ;初始化段基地址
    mov byte [LABEL_DESC_CODE32 + 7] , ah  ;初始化段基地址

    ;加载GDTR 做准备
    xor  eax, eax
    mov  ax, ds
    shl  eax, 4
    add eax, LABEL_GDT
    mov  dword [GdtPr + 2] , eax   ; ? + 2 初始化 Gdtpr 数据结构 dword : dd ?

    lgdt [GdtPr]

    ;关闭中断
    cli

    ;打开A20地址线     ; 要使cpu工作在32位模式下必须打开A20地址线，目的向上兼容（有溢出）
    in al, 92h
    or al, 00000010b
    out 92h, al

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
