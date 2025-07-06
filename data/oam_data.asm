OAMData:
;dummy troll sprite :3
db $FF,$FF,$B7,$69
;timing sprite for scanlines 63-71
db $4F,$01,$B9,$01

;TODO: find a better way to calculate the length of a symbol. Maybe a macro is
;needed?
def OAMDataLength equ 8