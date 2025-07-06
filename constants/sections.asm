;Section address constants

;VRAM addresses
def VRAM_ADDR equ $8000
def VRAM_BLOCK_SIZE equ $800
def VRAM_BLOCK_0 equ VRAM_ADDR
def VRAM_BLOCK_1 equ VRAM_ADDR + VRAM_BLOCK_SIZE
def VRAM_BLOCK_2 equ VRAM_ADDR + VRAM_BLOCK_SIZE*2

;OAM addresses
def OAM_ADDR equ $FE00
def OAM_UNUSED_ADDR equ $FEA0


;Stack pointer address
def STACK_ADDR equ $FFFE
