OAMData:
;Cleaned OAM data
db $18,$B7,$69,$00 ;dummy troll sprite :3
db $4F,$01,$B9,$01 ;timing sprite for scanlines 63-71

;original oam data
;db $18,$B7,$69,$00,$2F,$C0,$79,$65,$24,$85,$37,$81,$E9,$D4,$60,$F3
;db $D9,$A0,$A8,$8E,$4F,$01,$B9,$01,$7A,$F1,$72,$FB,$85,$C6,$B2,$1C
;db $70,$F9,$35,$DF,$E9,$5B,$DF,$0F,$9D,$94,$66,$59,$B9,$37,$D0,$E6
;db $0B,$4A,$DB,$58,$27,$52,$F3,$81,$F1,$59,$30,$7D,$FF,$9C,$8D,$22
;db $07,$39,$28,$06,$04,$CC,$67,$B2,$99,$E9,$44,$C6,$89,$32,$9C,$81
;db $69,$3A,$05,$11,$55,$DF,$AB,$02,$57,$00,$F2,$58,$FE,$A9,$E4,$55
;db $97,$7D,$11,$4B,$E2,$3D,$18,$89,$58,$8E,$EA,$39,$CB,$0A,$28,$38
;db $DF,$3B,$39,$D7,$F2,$CB,$DD,$75,$E8,$AF,$DF,$BA,$A1,$95,$47,$41
;db $97,$58,$B9,$5F,$52,$D1,$9B,$C0,$FA,$DC,$A5,$AB,$B5,$5A,$4E,$A9
;db $0B,$6B,$D0,$49,$18,$E2,$42,$3E,$31,$CC,$24,$2E,$CF,$BF,$DE,$55

;TODO: find a better way to calculate the length of a symbol. Maybe a macro is
;needed?
def OAMDataLength equ 8