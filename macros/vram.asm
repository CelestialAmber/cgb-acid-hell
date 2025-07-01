;1: register
;2: tile block
;3: tile id
macro tileaddr
    ld \1, (VRAM_START + (\2)*VRAM_BLOCK_SIZE) + (\3)*TILE_SIZE
endm