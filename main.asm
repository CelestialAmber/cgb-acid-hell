INCLUDE "includes.asm"

SECTION "Bank 0 Start", ROM0[$0000]

INCLUDE "src/header.asm"

SECTION "Bank 0 Code", ROM0[$0150]

INCLUDE "src/cgb-acid-hell.asm"

;Bank 1 is unused, and filled with FF unlike bank 0
SECTION "Bank 1", ROMX[$4000], BANK[$1]

rept 0x4000
    db $FF
endr