; =============================================================================
;   ai.asm - the CPU opponent
; =============================================================================
;   Ship 1 plans from the board as the turn began and never sees the person's
;   plan. It thinks a slice at a time during the person's planning (AiWork, once
;   a frame), so there's nothing to wait for.
;
;   Normal: it picks a hex that keeps a good distance and slides sideways off
;   the line a shot would come down, guesses where the enemy may end up (staying
;   put, or two hexes off in any of six directions), and tries a laser and a
;   torpedo at each of those places, keeping the shot that should do the most.
;   Easy: it closes in and shoots at where the enemy is now.
;   Its specials are in special.asm. A cloaked enemy is known only by where it
;   was last seen, and it knows nothing of the enemy's mines.
; =============================================================================

.segment "BANK00"

ME            = 1                  ; the CPU's ship
FOE           = 0

AI_MOVES      = 0                  ; AI_PHASE: scoring moves,
AI_SETUP      = 1                  ; getting ready to aim,
AI_AIMS       = 2                  ; scoring shots,
AI_DONE       = 3                  ; the plan is in
AI_FLAK       = 4                  ; or still weighing a flak shell

MOVES_A_SLICE = 4

DirQ:
  .byte 1, 0, $FF, $FF, 0, 1
DirR:
  .byte 0, 1, 1, 0, $FF, $FF
; Three moments in the turn, as eighths: 3/8, 5/8 and 7/8 of the way
SampleK:
  .byte 3, 5, 7
; A laser's burn a quarter-turn by distance in hexes
BurnByRange:
  .byte 25, 25, 25, 24, 23, 21, 20, 19, 18, 16, 15, 14, 13

; Rnd - a pseudo-random byte in A. Clobbers X.
Rnd:
  ldx #5
@step:
  asl RND
  rol RND+1
  bcc @next
  lda RND
  eor #$2D
  sta RND
@next:
  dex
  bne @step
  lda RND
  rts

; HexStep - (AI_HC, AI_HR) moved by axial (AI_HQ, AI_HS) into (AI_OC, AI_OR).
; Carry set if that's on the board.
HexStep:
  ldx AI_HR
  lda AI_HC
  sec
  sbc FloorHalf,x
  clc
  adc AI_HQ
  sta AI_TMP
  lda AI_HR
  clc
  adc AI_HS
  cmp #ROWS
  bcs @off
  sta AI_OR
  tax
  lda AI_TMP
  clc
  adc FloorHalf,x
  sta AI_OC
  txa
  jsr RowLen
  sta AI_TMP
  lda AI_OC
  cmp AI_TMP
  bcs @off
  sec
  rts
@off:
  clc
  rts

; Interp - AI_A + (AI_B - AI_A) * AI_F / 8, in A.
Interp:
  lda AI_B
  sec
  sbc AI_A
  sta MB
  lda #0
  sbc #0
  sta MB+1
  lda AI_F
  sta MA
  jsr SMul
  ldx #3
@shift:
  lda PROD+1
  cmp #$80
  ror PROD+1
  ror PROD
  dex
  bne @shift
  lda PROD
  clc
  adc AI_A
  rts

; AddEnd - (AI_OC, AI_OR) is somewhere the enemy may finish, weight A.
AddEnd:
  ldy AI_N
  sta AI_EW,y
  lda AI_OC
  sta AI_EC,y
  lda AI_OR
  sta AI_ER,y
  ldx AI_OC
  phy
  ldy AI_OR
  jsr HexCenter
  ply
  lda HX
  sta AI_EPX,y
  lda HY
  sta AI_EPY,y
  inc AI_N
  rts

; AiStart - begin planning ship ME's turn.
AiStart:
  stz AI_PHASE
  lda #$FD
  sta AI_Q
  sta AI_R
  stz AI_BEST
  lda SHIP_C+ME
  sta AI_BC
  lda SHIP_R+ME
  sta AI_BR
  ldx #ME
  jsr ShipCenter
  lda HX
  sta AI_SX
  lda HY
  sta AI_SY
  ; where it knows the enemy to be
  lda CLOAKED+FOE
  sta AI_HIDDEN
  beq @inSight
  lda SEEN_C+FOE
  sta AI_KC
  lda SEEN_R+FOE
  sta AI_KR
  bra @located
@inSight:
  lda SHIP_C+FOE
  sta AI_KC
  lda SHIP_R+FOE
  sta AI_KR
@located:
  ldx AI_KC
  ldy AI_KR
  jsr HexCenter
  lda HX
  sta AI_FX
  lda HY
  sta AI_FY
  ; the line between the two ships
  lda AI_FX
  sec
  sbc AI_SX
  sta SD_DX
  lda #0
  sbc #0
  sta SD_DX+1
  lda AI_FY
  sec
  sbc AI_SY
  sta SD_DY
  lda #0
  sbc #0
  sta SD_DY+1
  jsr ScaleDir
  jsr DirLength
  lda DIRX
  sta AI_LX
  lda DIRY
  sta AI_LY
  lda LEN
  sta AI_LL
  ; where the enemy may end: staying counts more if it stayed last turn
  stz AI_N
  lda AI_KC
  sta AI_OC
  sta AI_HC
  lda AI_KR
  sta AI_OR
  sta AI_HR
  stz AI_STAYED
  ldy #1
  lda AI_HIDDEN
  bne @weight
  ldy #2
  lda AI_OC
  cmp AI_LC
  bne @weight
  lda AI_OR
  cmp AI_LR
  bne @weight
  ldy #5
  inc AI_STAYED
@weight:
  tya
  jsr AddEnd
  lda AI_KC
  sta AI_LC
  lda AI_KR
  sta AI_LR
  stz AI_I
@dir:
  ldx AI_I                         ; 2 hexes off, or 3 if it's out of sight
  ldy AI_HIDDEN
  lda DirQ,x
  asl a
  cpy #0
  beq @setQ
  clc
  adc DirQ,x
@setQ:
  sta AI_HQ
  lda DirR,x
  asl a
  cpy #0
  beq @setR
  clc
  adc DirR,x
@setR:
  sta AI_HS
  jsr HexStep
  bcc @nextDir
  lda #1
  jsr AddEnd
@nextDir:
  inc AI_I
  lda AI_I
  cmp #6
  bne @dir
  ; where each could be at the three moments
  stz AI_I
@end:
  lda AI_I
  asl a
  clc
  adc AI_I
  sta AI_K                         ; index of this end's first moment
  stz AI_S
@moment:
  ldx AI_S
  lda SampleK,x
  sta AI_F
  lda AI_FX
  sta AI_A
  ldy AI_I
  lda AI_EPX,y
  sta AI_B
  jsr Interp
  pha
  lda AI_K
  clc
  adc AI_S
  tay
  pla
  sta AI_TX,y
  lda AI_FY
  sta AI_A
  ldy AI_I
  lda AI_EPY,y
  sta AI_B
  jsr Interp
  pha
  lda AI_K
  clc
  adc AI_S
  tay
  pla
  sta AI_TY,y
  inc AI_S
  lda AI_S
  cmp #3
  bne @moment
  inc AI_I
  lda AI_I
  cmp AI_N
  bne @end
  rts

; AiWork - one slice of thinking.
AiWork:
  lda AI_PHASE
  beq AiMoves
  cmp #AI_SETUP
  bne @more
  jmp AiSetup
@more:
  cmp #AI_AIMS
  bne @flak
  jmp AiAim
@flak:
  cmp #AI_FLAK
  bne @done
  jmp AiFlak
@done:
  rts

; AiFinish - think until the plan is in.
AiFinish:
  jsr AiWork
  lda AI_PHASE
  cmp #AI_DONE
  bne AiFinish
  rts

; AiMoves - score some of the hexes within reach.
AiMoves:
  lda #MOVES_A_SLICE
  sta AI_CNT
@loop:
  lda AI_Q
  clc
  adc AI_R
  jsr Abs8
  cmp #MOVE_RANGE + 1
  bcs @skip
  lda SHIP_C+ME
  sta AI_HC
  lda SHIP_R+ME
  sta AI_HR
  lda AI_Q
  sta AI_HQ
  lda AI_R
  sta AI_HS
  jsr HexStep
  bcc @skip
  jsr ScoreMove
  dec AI_CNT
@skip:
  inc AI_R
  lda AI_R
  cmp #MOVE_RANGE + 1
  bne @more
  lda #$FD
  sta AI_R
  inc AI_Q
  lda AI_Q
  cmp #MOVE_RANGE + 1
  bne @more
  lda #AI_SETUP
  sta AI_PHASE
  rts
@more:
  lda AI_CNT
  bne @loop
  rts

; ScoreMove - how good ending on (AI_OC, AI_OR) looks.
ScoreMove:
  lda #100
  sta AI_S
  lda AI_OC
  sta HD_C1
  lda AI_OR
  sta HD_R1
  lda AI_KC
  sta HD_C2
  lda AI_KR
  sta HD_R2
  jsr HexDist
  sta AI_TMP
  bne @apart
  lda #90                          ; not on top of the enemy
  sta AI_S
@apart:
  ; the distance it wants: near when easy, or by who's ahead
  ldy #2
  lda OPP
  bne @want
  ldy #4
  lda SHIP_HP_HI+ME
  cmp SHIP_HP_HI+FOE
  bcs @want
  ldy #6
@want:
  tya
  sec
  sbc AI_TMP
  jsr Abs8
  sta AI_TMP
  asl a
  clc
  adc AI_TMP                       ; 3 points a hex off
  sta AI_TMP
  lda AI_S
  sec
  sbc AI_TMP
  sta AI_S
  lda OPP
  beq @normal
  jsr Rnd
  and #15
  jmp @add
@normal:
  ; sideways off the line between the ships is worth the most
  ldx AI_OC
  ldy AI_OR
  jsr HexCenter
  lda AI_LX
  sta MA
  lda HY
  sec
  sbc AI_SY
  sta MB
  lda #0
  sbc #0
  sta MB+1
  jsr SMul
  lda PROD
  sta CROSS
  lda PROD+1
  sta CROSS+1
  lda AI_LY
  sta MA
  lda HX
  sec
  sbc AI_SX
  sta MB
  lda #0
  sbc #0
  sta MB+1
  jsr SMul
  lda CROSS
  sec
  sbc PROD
  sta DIVIDEND
  lda CROSS+1
  sbc PROD+1
  sta DIVIDEND+1
  bpl @pos
  lda DIVIDEND
  eor #$FF
  clc
  adc #1
  sta DIVIDEND
  lda DIVIDEND+1
  eor #$FF
  adc #0
  sta DIVIDEND+1
@pos:
  lda AI_LL
  beq @edge
  sta DIVISOR
  jsr Div16
  lda QUOT
  cmp #40
  bcc @side
  lda #40
@side:
  lsr a
  clc
  adc AI_S
  sta AI_S
@edge:
  ; the rim leaves less room to dodge next turn
  lda AI_OR
  beq @rim
  cmp #ROWS - 1
  beq @rim
  lda AI_OC
  beq @rim
  lda AI_OR
  jsr RowLen
  dec a
  cmp AI_OC
  bne @jitter
@rim:
  lda AI_S
  sec
  sbc #4
  sta AI_S
@jitter:
  jsr Rnd
  and #7
@add:
  clc
  adc AI_S
  cmp AI_BEST
  bcc @done
  sta AI_BEST
  lda AI_OC
  sta AI_BC
  lda AI_OR
  sta AI_BR
@done:
  rts

; AiSetup - the move is chosen: work out where the ship will be.
AiSetup:
  ldx AI_BC
  ldy AI_BR
  jsr HexCenter
  lda HX
  sta AI_DX
  lda HY
  sta AI_DY
  ldy #0
@moment:
  phy
  lda SampleK,y
  sta AI_F
  lda AI_SX
  sta AI_A
  lda AI_DX
  sta AI_B
  jsr Interp
  ply
  sta AI_PX,y
  phy
  lda AI_SY
  sta AI_A
  lda AI_DY
  sta AI_B
  jsr Interp
  ply
  sta AI_PY,y
  iny
  cpy #3
  bne @moment
  ; aim at where the enemy is unless something scores better
  lda AI_KC
  sta AI_BAC
  lda AI_KR
  sta AI_BAR
  stz AI_BW
  ldx #1
@clear:
  stz AI_BS_LO,x
  stz AI_BS_HI,x
  lda AI_KC
  sta AI_BA_C,x
  lda AI_KR
  sta AI_BA_R,x
  dex
  bpl @clear
  lda AI_BC
  sta HD_C1
  lda AI_BR
  sta HD_R1
  lda AI_KC
  sta HD_C2
  lda AI_KR
  sta HD_R2
  jsr HexDist
  sta AI_TMP
  cmp #13
  bcc @near
  lda #12
@near:
  tax
  lda BurnByRange,x
  sta AI_BURN
  lda OPP
  beq @normal
  ; easy: lasers up close, otherwise either weapon
  lda AI_TMP
  cmp #5
  bcc @commit
  jsr Rnd
  and #1
  sta AI_BW
@commit:
  jmp AiSpecial
@normal:
  stz AI_I
  stz AI_SUB
  lda #AI_AIMS
  sta AI_PHASE
  rts

; AiAim - one slice of trying the weapons at one of the enemy's possible ends:
; the laser at each of the three moments, then the torpedo.
AiAim:
  ldy AI_I
  lda AI_EPX,y
  sta AI_AX
  lda AI_EPY,y
  sta AI_AY
  lda AI_SUB
  cmp #3
  beq @torpedo
  sta AI_S
  bne @moment
  stz AI_SC
  stz AI_SC+1
@moment:
  jsr LaserMoment
  inc AI_SUB
  lda AI_SUB
  cmp #3
  bne @done
  stz AI_W
  jmp KeepShot
@torpedo:
  jsr ScoreTorpedo
  lda #W_TORPEDO
  sta AI_W
  jsr KeepShot
  stz AI_SUB
  inc AI_I
  lda AI_I
  cmp AI_N
  bne @done
  jmp AiChoose
@done:
  rts

; KeepShot - AI_SC, plus a little noise, against weapon AI_W's best so far.
KeepShot:
  jsr Rnd
  and #15
  clc
  adc AI_SC
  sta AI_SC
  bcc @noCarry
  inc AI_SC+1
@noCarry:
  ldx AI_W
  lda AI_SC
  cmp AI_BS_LO,x
  lda AI_SC+1
  sbc AI_BS_HI,x
  bcc @done
  lda AI_SC
  sta AI_BS_LO,x
  lda AI_SC+1
  sta AI_BS_HI,x
  ldy AI_I
  lda AI_EC,y
  sta AI_BA_C,x
  lda AI_ER,y
  sta AI_BA_R,x
@done:
  rts

; AiChoose - laser or torpedo. A laser usually promises more, but only if the
; enemy holds still, so a torpedo that's at least half as good gets its turn
; now and then, more often against an enemy that's been moving.
AiChoose:
  ldx #W_LASER
  lda AI_BS_LO+W_TORPEDO
  cmp AI_BS_LO+W_LASER
  lda AI_BS_HI+W_TORPEDO
  sbc AI_BS_HI+W_LASER
  bcs @torpedo                     ; better outright
  lda AI_BS_HI+W_LASER             ; half the laser's score
  lsr a
  sta AI_TMP
  lda AI_BS_LO+W_LASER
  ror a
  cmp AI_BS_LO+W_TORPEDO
  lda AI_TMP
  sbc AI_BS_HI+W_TORPEDO
  bcs @pick                        ; not close enough
  jsr Rnd
  and #7
  ldy AI_STAYED
  bne @still
  cmp #3                           ; 3 in 8 against a moving enemy
  bcs @laser
  bra @torpedo
@still:
  cmp #1                           ; 1 in 8 against one holding still
  bcs @laser
@torpedo:
  ldx #W_TORPEDO
  bra @pick
@laser:
  ldx #W_LASER
@pick:
  stx AI_BW
  lda AI_BA_C,x
  sta AI_BAC
  lda AI_BA_R,x
  sta AI_BAR
  jmp AiSpecial

; AddScore - weight of end AI_K times A onto AI_SC.
AddScore:
  ldy AI_K
  ldx AI_EW,y
  jsr Mul8
  lda PROD
  clc
  adc AI_SC
  sta AI_SC
  lda PROD+1
  adc AI_SC+1
  sta AI_SC+1
  rts

; SetV - VX, VY = the enemy at end AI_K, moment AI_S, less (AI_A, AI_B).
SetV:
  lda AI_K
  asl a
  clc
  adc AI_K
  adc AI_S
  tay
  lda AI_TX,y
  sec
  sbc AI_A
  sta VX
  lda #0
  sbc #0
  sta VX+1
  lda AI_TY,y
  sec
  sbc AI_B
  sta VY
  lda #0
  sbc #0
  sta VY+1
  rts

; LaserMoment - what a beam held on (AI_AX, AI_AY) should burn at moment AI_S:
; each place the enemy may be that's on the line counts.
LaserMoment:
  ldy AI_S
  lda AI_PX,y
  sta AI_A
  lda AI_PY,y
  sta AI_B
  lda AI_AX
  sec
  sbc AI_A
  sta SD_DX
  lda #0
  sbc #0
  sta SD_DX+1
  lda AI_AY
  sec
  sbc AI_B
  sta SD_DY
  lda #0
  sbc #0
  sta SD_DY+1
  jsr ScaleDir
  beq @done
  jsr DirLength
  lda LEN
  beq @done
  stz AI_K
@end:
  jsr SetV
  jsr LineTest
  bcc @miss
  lda AI_BURN
  jsr AddScore
@miss:
  inc AI_K
  lda AI_K
  cmp AI_N
  bne @end
@done:
  rts

; ScoreTorpedo - what a torpedo from the ship's start through the aim should
; do: it counts if the enemy would be on its line by the time it gets there.
ScoreTorpedo:
  stz AI_SC
  stz AI_SC+1
  lda AI_SX
  sta AI_A
  lda AI_SY
  sta AI_B
  lda AI_AX
  sec
  sbc AI_A
  sta SD_DX
  lda #0
  sbc #0
  sta SD_DX+1
  lda AI_AY
  sec
  sbc AI_B
  sta SD_DY
  lda #0
  sbc #0
  sta SD_DY+1
  jsr ScaleDir
  beq @done
  jsr DirLength
  lda LEN
  beq @done
  stz AI_K
@end:
  lda #1                           ; first, roughly how far along it is
  sta AI_S
  jsr SetV
  jsr LineTest
  lda DOT+1
  bmi @next
  lda DOT
  sta DIVIDEND
  lda DOT+1
  sta DIVIDEND+1
  lda LEN
  sta DIVISOR
  jsr Div16
  ; the torpedo covers 60 pixels a quarter-turn: pick the moment it arrives
  stz AI_S
  lda QUOT+1
  bne @late
  lda QUOT
  cmp #120
  bcc @test
  inc AI_S
  cmp #180
  bcc @test
@late:
  lda #2
  sta AI_S
@test:
  jsr SetV
  jsr LineTest
  bcc @next
  ldy SHIP_FACTION+ME              ; counted half again: it lands all at once
  lda TorpedoDamage,y
  sta AI_TMP
  lsr a
  clc
  adc AI_TMP
  jsr AddScore
@next:
  inc AI_K
  lda AI_K
  cmp AI_N
  bne @end
@done:
  rts

; AiCommit - write the plan.
AiCommit:
  lda AI_BC
  sta PLAN_C+ME
  lda AI_BR
  sta PLAN_R+ME
  lda AI_BAC
  sta AIM_C+ME
  lda AI_BAR
  sta AIM_R+ME
  lda AI_BW
  sta PLAN_WEAPON+ME
  lda AI_SPEC
  sta PLAN_SPECIAL+ME
  lda #AI_DONE
  sta AI_PHASE
  rts
