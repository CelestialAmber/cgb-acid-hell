INCLUDE "includes.asm"

SECTION "Bank 0 Start", ROM0[$0000]

INCLUDE "src/header.asm"

SECTION "Bank 0", ROM0[$0150]

INCLUDE "src/main.asm"
INCLUDE "data/palettes.asm"
INCLUDE "gfx/faces.asm"
;Split off from the tilemap if the deobfuscate flag is on
if DEF(DEOBFUSCATE)
    INCLUDE "data/oam_data.asm"
endc
INCLUDE "gfx/tilemap.asm"
INCLUDE "gfx/messages.asm"

;Bank 1 is unused, and filled with FF unlike bank 0
SECTION "Bank 1", ROMX[$4000], BANK[$1]

rept 0x4000
    db $FF
endr