; 描述符信息
; usage : Descriptor Base, Limit , Attr
;       Base : dd
;       Limit : dd (low 20 bits avaliable)
;       Attr: dw (lower 4 bits of higher byte are always 0)

DA_32   EQU   4000h
DA_DR    EQU  90h
DA_C     EQU  98h
DA_DRW   EQU  92h

%macro Descriptor 3
    dw  %2 & 0FFFFh    ;段界1
    dw %1  & 0FFFFh   ;段基址1
    db (%1 >> 16) & 0FFh ; 段基址2 
    dw ((%2 >> 8) & 0f00h | (%3 & 0f0ffh)) ; 属性 + 断界限2 + 属性2
    db (%1 >> 24) & 0ffh    ; 段基址3
%endmacro

