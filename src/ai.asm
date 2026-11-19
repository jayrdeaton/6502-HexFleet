; =============================================================================
;   ai.asm - the CPU opponent
; =============================================================================
;   Each CPU seat plans in turn, from the board as the turn began, and never sees
;   a person's plan. It thinks a slice at a time during the people's planning
;   (AiWork, once a frame), so there's little to wait for. It watches its nearest
;   enemy, and a teammate is something not to shoot or fly into.
;
;   Normal: it picks a hex that keeps a good distance and slides sideways off
;   the line a shot would come down, guesses where the enemy may end up (staying
;   put, or two hexes off in any of six directions), and tries a laser and a
;   torpedo at each of those places, keeping the shot that should do the most.
;   Easy: it closes in and shoots at where the enemy is now.
;   Its specials are in special.asm. A cloaked enemy is known only by where it
;   was last seen, and it knows nothing of the enemy's mines.
; =============================================================================

.segment "BANK04"

AI_MOVES      = 0                  ; AI_PHASE: scoring moves,
AI_SETUP      = 1                  ; getting ready to aim,
AI_AIMS       = 2                  ; scoring shots,
AI_DONE       = 3                  ; the plan is in
AI_FLAK       = 4                  ; or still weighing a flak shell
AI_NEXT       = 5                  ; on to the next CPU seat
AI_IDLE       = AI_DONE
AI_BANK       = 4

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

.segment "CART"

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

.segment "BANK04"

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

; AiBegin4 - a new turn: the first CPU seat is up next.
AiBegin4:
  ldx #NUM_SHIPS - 1
@ship:
  stz PLANNED,x
  dex
  bpl @ship
  lda #$FF
  sta AI_ME
  lda #AI_NEXT
  sta AI_PHASE
  rts

; AiNextSeat - start the next CPU seat with an enemy to fight, or finish.
AiNextSeat:
  inc AI_ME
  ldx AI_ME
  cpx N_SHIPS
  bcs @done
  lda SHIP_ALIVE,x
  beq AiNextSeat
  lda SEAT_KIND,x
  beq AiNextSeat
  jsr AiLoadSeat
  bcc AiNextSeat
  jmp AiStart
@done:
  lda #AI_DONE
  sta AI_PHASE
  rts

; AiLoadSeat - seat X's own details, its nearest enemy and its teammate. Carry clear
; if it has no enemy left.
AiLoadSeat:
  lda SHIP_C,x
  sta AI_MC
  sta HD_C1
  lda SHIP_R,x
  sta AI_MR
  sta HD_R1
  lda SHIP_HP_HI,x
  sta AI_MHP
  lda SHIP_FACTION,x
  sta AI_MFAC
  lda SPECIAL_WAIT,x
  sta AI_MWAIT
  stz AI_EASY
  lda SEAT_KIND,x
  cmp #KIND_EASY
  bne @kind
  inc AI_EASY
@kind:
  lda #$FF
  sta AI_FOE
  sta AI_MATE
  sta AI_TMP2
  stz AI_CNT
@seat:
  ldy AI_CNT
  cpy N_SHIPS
  bcs @picked
  cpy AI_ME
  beq @next
  lda SHIP_ALIVE,y
  beq @next
  ldx AI_ME
  lda SHIP_SIDE,y
  cmp SHIP_SIDE,x
  bne @enemy
  sty AI_MATE                      ; on our side
  lda SHIP_C,y                     ; where it's going, if it has already chosen
  ldx PLANNED,y
  beq @mateHex
  lda PLAN_C,y
@mateHex:
  sta AI_MTC
  lda SHIP_R,y
  ldx PLANNED,y
  beq @mateRow
  lda PLAN_R,y
@mateRow:
  sta AI_MTR
  bra @next
@enemy:
  lda CLOAKED,y                    ; a cloaked ship is only where it was last seen
  beq @seen
  lda SEEN_C,y
  sta HD_C2
  lda SEEN_R,y
  sta HD_R2
  bra @measure
@seen:
  lda SHIP_C,y
  sta HD_C2
  lda SHIP_R,y
  sta HD_R2
@measure:
  jsr HexDist
  cmp AI_TMP2
  bcs @next
  sta AI_TMP2
  lda AI_CNT
  sta AI_FOE
@next:
  inc AI_CNT
  bra @seat
@picked:
  ldy AI_FOE
  cpy #$FF
  beq @noEnemy
  lda SHIP_HP_HI,y
  sta AI_FHP
  sec
  rts
@noEnemy:
  clc
  rts

; AiStart - begin planning seat AI_ME's turn.
AiStart:
  stz AI_PHASE
  lda #$FD
  sta AI_Q
  sta AI_R
  stz AI_BEST
  lda AI_MC
  sta AI_BC
  lda AI_MR
  sta AI_BR
  ldx AI_MC
  ldy AI_MR
  jsr HexCenter
  lda HX
  sta AI_SX
  lda HY
  sta AI_SY
  ; where it knows the enemy to be
  ldy AI_FOE
  lda CLOAKED,y
  sta AI_HIDDEN
  beq @inSight
  lda SEEN_C,y
  sta AI_KC
  lda SEEN_R,y
  sta AI_KR
  bra @located
@inSight:
  lda SHIP_C,y
  sta AI_KC
  lda SHIP_R,y
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
  ldx AI_FOE
  lda STAYED,x
  beq @weight
  ldy #5
  inc AI_STAYED
@weight:
  tya
  jsr AddEnd
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

; AiWork4 - one slice of thinking.
AiWork4:
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
  bne @next
  jmp AiFlak
@next:
  cmp #AI_NEXT
  bne @done
  jmp AiNextSeat
@done:
  rts

; AiFinish4 - think until every plan is in.
AiFinish4:
  lda AI_PHASE
  cmp #AI_DONE
  beq @done
  jsr AiWork4
  bra AiFinish4
@done:
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
  lda AI_MC
  sta AI_HC
  lda AI_MR
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
  lda AI_EASY
  bne @want
  ldy #4
  lda AI_MHP
  cmp AI_FHP
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
  lda AI_EASY
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
  jsr MatePenalty
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

; NearMate - carry set if (AI_OC, AI_OR) is on or beside where the teammate will be.
NearMate:
  lda AI_MATE
  bmi @no
  lda AI_OC
  sta HD_C1
  lda AI_OR
  sta HD_R1
  lda AI_MTC
  sta HD_C2
  lda AI_MTR
  sta HD_R2
  jsr HexDist
  cmp #2
  bcs @no
  sec
  rts
@no:
  clc
  rts

; MatePenalty - this hex is worth less beside the teammate or its mines.
MatePenalty:
  lda AI_MATE
  bmi @done
  jsr NearMate
  bcc @mines
  lda #8
  jsr LessScore
@mines:
  ldy #NUM_MINES - 1
@mine:
  lda MINE_OWNER,y
  beq @next
  dec a
  cmp AI_MATE
  bne @next
  lda MINE_C,y
  sta HD_C2
  lda MINE_R,y
  sta HD_R2
  phy
  jsr HexDist
  ply
  cmp #2
  bcs @next
  lda #25
  jsr LessScore
@next:
  dey
  bpl @mine
@done:
  rts

LessScore:
  sta AI_TMP
  lda AI_S
  sec
  sbc AI_TMP
  bcs @left
  lda #0
@left:
  sta AI_S
  rts

; MateMoments - where the teammate will be at the three moments.
MateMoments:
  lda AI_MATE
  bmi @done
  tay
  ldx SHIP_C,y
  lda SHIP_R,y
  tay
  jsr HexCenter
  lda HX
  sta AI_OC
  lda HY
  sta AI_OR
  ldx AI_MTC
  ldy AI_MTR
  jsr HexCenter
  stz AI_CNT
@moment:
  ldy AI_CNT
  lda SampleK,y
  sta AI_F
  lda AI_OC
  sta AI_A
  lda HX
  sta AI_B
  jsr Interp
  ldy AI_CNT
  sta AI_MX,y
  lda AI_OR
  sta AI_A
  lda HY
  sta AI_B
  jsr Interp
  ldy AI_CNT
  sta AI_MY,y
  inc AI_CNT
  lda AI_CNT
  cmp #3
  bne @moment
@done:
  rts

; MateOnLine - would the line from (AI_A, AI_B) touch the teammate at moment A?
MateOnLine:
  tay
  lda AI_MATE
  bmi @done
  lda AI_MX,y
  sec
  sbc AI_A
  sta VX
  lda #0
  sbc #0
  sta VX+1
  lda AI_MY,y
  sec
  sbc AI_B
  sta VY
  lda #0
  sbc #0
  sta VY+1
  jsr LineTest
  bcc @done
  lda #1
  sta AI_BAD
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
  jsr MateMoments
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
  lda AI_EASY
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
  stz AI_BAD
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

; KeepShot - AI_SC, plus a little noise, against weapon AI_W's best so far. A shot
; that would hit the teammate doesn't count.
KeepShot:
  lda AI_BAD
  beq @fair
  rts
@fair:
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
  lda AI_S
  jsr MateOnLine
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
  stz AI_BAD
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
  lda #0
  jsr MateOnLine
  lda #1
  jsr MateOnLine
  lda #2
  jsr MateOnLine
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
  ldy AI_MFAC              ; counted half again: it lands all at once
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

; AiCommit - write this seat's plan, and on to the next.
AiCommit:
  ldx AI_ME
  lda AI_BC
  sta PLAN_C,x
  lda AI_BR
  sta PLAN_R,x
  lda AI_BAC
  sta AIM_C,x
  lda AI_BAR
  sta AIM_R,x
  lda AI_BW
  sta PLAN_WEAPON,x
  lda AI_SPEC
  sta PLAN_SPECIAL,x
  lda #1
  sta PLANNED,x
  lda #AI_NEXT
  sta AI_PHASE
  rts
