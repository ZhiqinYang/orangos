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

   
    ;cli 指令简介：
    ; CLI(clear interrupt)是将处理器标志寄存器的中断标志位清0，不允许中断,防止硬件干扰。
    ; CLI经常与STI(set interrupt)成对使用，STI的是将处理器标志寄存器的中断标志置1，允许中断。
    
    ;关闭中断
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

   
    ;cr0 寄存器简介：
    ;控制寄存器（CR0～CR3）用于控制和确定处理器的操作模式以及当前执行任务的特性,CR0中含有控制处理器
    ;操作模式和状态的系统控制标志；CR1保留不用；CR2含有导致页错误的线性地址；CR3中含有页目录表物理内
    ;存基地址，因此该寄存器也被称为页目录基地址寄存器PDBR（Page-Directory Base address Register）。

    ;（1）PE：CR0的位0是启用保护（Protection Enable）标志。当设置该位时即开启了保护模式；当复位时即进入实地址模式。
    ;         这个标志仅开启段级保护，而并没有启用分页机制。若要启用分页机制，那么PE和PG标志都要置位。
    ;（2）PG：CR0的位31是分页（Paging）标志。当设置该位时即开启了分页机制；当复位时则禁止分页机制，此时所有线性地址
    ;         等同于物理地址。在开启这个标志之前必须已经或者同时开启PE标志。即若要启用分页机制，那么PE和PG标志都要置位。
    ;（3）WP：对于Intel 80486或以上的CPU，CR0的位16是写保护（Write Proctect）标志。当设置该标志时，处理器会禁止超级
    ;         用户程序（例如特权级0的程序）向用户级只读页面执行写操作；当该位复位时则反之。该标志有利于UNIX类操作系
    ;         统在创建进程时实现写时复制（Copy on Write）技术。
    ;（4）NE：对于Intel 80486或以上的CPU，CR0的位5是协处理器错误（Numeric Error）标志。当设置该标志时，就启用了x87协
    ;         处理器错误的内部报告机制；若复位该标志，那么就使用PC形式的x87协处理器错误报告机制。当NE为复位状态并且
    ;         CPU的IGNNE输入引脚有信号时，那么数学协处理器x87错误将被忽略。当NE为复位状态并且CPU的IGNNE输入引脚无信号时，那么非屏蔽的数学协处理器x87错误将导致处理器通过FERR引脚在外部产生一个中断，并且在执行下一个等待形式浮点指令或WAIT/FWAIT指令之前立刻停止指令执行。CPU的FERR引脚用于仿真外部协处理器80387的ERROR引脚，因此通常连接到中断控制器输入请求引脚上。NE标志、IGNNE引脚和FERR引脚用于利用外部逻辑来实现PC形式的外部错误报告机制。
    
    
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
