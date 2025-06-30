MACRO ld_long
    IF STRLWR("\1") == "a"
        ; ld a, [rLCDC]
        db $FA
        dw \2
    ELSE
        IF STRLWR("\2") == "a"
            ; ld [rLCDC], a
            db $EA
            dw \1
        ENDC
    ENDC
ENDM
