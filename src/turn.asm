; =============================================================================
;   turn.asm - a turn playing out: the rules and the picture together
; =============================================================================
;   HexFleet's rules, in whole numbers. There are no dice: every ship glides
;   to its hex across the whole turn, and a hit is contact. A laser charges for
;   the first quarter of the turn, then burns whatever its line first touches
;   for 25 hull a quarter, less at long range. A torpedo flies from where its
;   ship started, through the aim and on, and hits the first ship it touches.
; =============================================================================

.segment "BANK00"

; A laser's burn each tick by distance in hexes, in 1/256 hull: 25 a quarter
; (16 ticks) up to 2 hexes, then 5% less a hex, never under half.
BurnLo:
  .byte <400, <400, <400, <380, <360, <340, <320, <300, <280, <260, <240, <220, <200
BurnHi:
  .byte >400, >400, >400, >380, >360, >340, >320, >300, >280, >260, >240, >220, >200

SqTab:
  .byte 0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100

; RunTurn - play the turn every ship has planned.
RunTurn:
  jsr CanvasClear
  jsr HideSeen
  jsr ArmOldMines
  stz ANY
  ldx #0
@setup:
  stz TORP_ON,x
  stz TORP_FLASH,x
  stz FIRING,x
  stz EXPL_T,x
  stz JUMPING,x
  stz ON_FIELD,x
  lda #$FF
  sta BEAM_TGT,x
  lda SHIP_ALIVE,x
  beq @gone
  inc ON_FIELD,x
  jsr StartSpecial
  jsr SetupShip
  bra @next
@gone:
  stz CLOAKED,x
@next:
  inx
  cpx N_SHIPS
  bne @setup
  lda ANY
  beq @quiet
  jsr SndTorpedo
@quiet:
  jsr ThrustSound
  lda S_TICKS
  sta TICK_MARK
  stz TICK
  stz EXTRA
  stz REDRAW
@tick:
  jsr MoveShips
  jsr MoveTorpedoes
  jsr CheckMines
  jsr LandJumps
  jsr BurnLasers
  jsr FlakBursts
  jsr CheckWrecks
  jsr UpdateFx
  jsr DrawBeams
  jsr DrawSprites
  jsr DrawHulls
  jsr TickWait
  inc TICK
  lda TICK
  cmp #TICKS
  bcc @tick
  bne @late
  lda #1
  sta REDRAW                       ; the beams go out
@late:
  jsr SndLaserOff
  jsr StillBusy                    ; torpedoes in flight, wrecks burning
  beq @end
  inc EXTRA
  lda EXTRA
  cmp #EXTRA_TICKS
  bcc @tick
@end:
  ldx #NUM_FX - 1
@noFx:
  stz FX_T,x
  dex
  bpl @noFx
  jsr ShowFx
  jsr CanvasClear
  ldx #0
@settle:
  lda PLAN_C,x
  sta SHIP_C,x
  lda PLAN_R,x
  sta SHIP_R,x
  lda SLOT_TORP_HIDE,x
  phx
  tax
  jsr HideSprite
  plx
  lda SLOT_EXPL_HIDE,x
  phx
  tax
  jsr HideSprite
  plx
  jsr DrawHpLine
  inx
  cpx N_SHIPS
  bne @settle
  jsr ShowBoard
  jmp UploadSprites

SLOT_TORP_HIDE:
  .byte SLOT_TORP, SLOT_TORP + 1, SLOT_TORP + 2, SLOT_TORP + 3
SLOT_EXPL_HIDE:
  .byte SLOT_EXPL, SLOT_EXPL + 1, SLOT_EXPL + 2, SLOT_EXPL + 3

; TickWait - hold each tick of the turn to its time by the sound timer, so a busy
; tick is made up by a shorter wait. Without the timer, count frames.
TickWait:
  lda S_ON
  beq @frames
@wait:
  lda S_TICKS
  sec
  sbc TICK_MARK
  cmp #FRAMES_A_TICK
  bcc @wait
  cmp #8
  bcc @onTime
  lda S_TICKS                      ; far behind: don't try to catch up
  sta TICK_MARK
  rts
@onTime:
  lda TICK_MARK
  clc
  adc #FRAMES_A_TICK
  sta TICK_MARK
  rts
@frames:
  lda #FRAMES_A_TICK
  jmp WaitFrames

; StillBusy - Z clear while anything is left to finish.
StillBusy:
  ldx N_SHIPS
  dex
@loop:
  lda TORP_ON,x
  ora TORP_FLASH,x
  ora EXPL_T,x
  bne @done
  dex
  bpl @loop
  ldx #NUM_FX - 1
@fx:
  lda FX_T,x
  bne @done
  dex
  bpl @fx
  lda #0
@done:
  rts

; SetupShip - ship X's course, heading and shot. Keeps X.
SetupShip:
  stx TI
  jsr ShipCenter
  lda HX
  sta POS_X_HI,x
  stz POS_X_LO,x
  lda HY
  sta POS_Y_HI,x
  stz POS_Y_LO,x
  ; where it's going: velocity is the distance * 4 (64 ticks, 8.8 pixels)
  ldy PLAN_R,x
  lda PLAN_C,x
  tax
  jsr HexCenter
  ldx TI
  lda HX
  sec
  sbc POS_X_HI,x
  sta HDX
  lda #0
  sbc #0
  sta HDX+1
  lda HY
  sec
  sbc POS_Y_HI,x
  sta HDY
  lda #0
  sbc #0
  sta HDY+1
  lda HDX
  sta T0
  lda HDX+1
  sta T1
  asl T0
  rol T1
  asl T0
  rol T1
  lda T0
  sta VEL_X_LO,x
  lda T1
  sta VEL_X_HI,x
  lda HDY
  sta T0
  lda HDY+1
  sta T1
  asl T0
  rol T1
  asl T0
  rol T1
  lda T0
  sta VEL_Y_LO,x
  lda T1
  sta VEL_Y_HI,x
  jsr HeadingOf
  ldx TI
  cmp #$FF
  beq @noTurn
  sta SHIP_HEAD,x
@noTurn:
  lda PLAN_SPECIAL,x
  beq @aim
  lda SHIP_FACTION,x
  cmp #SP_JUMP
  bne @aim
  jsr StartJump
@aim:
  ldy AIM_R,x
  lda AIM_C,x
  tax
  jsr HexCenter
  ldx TI
  lda HX
  sta AIM_X,x
  lda HY
  sta AIM_Y,x
  lda PLAN_SPECIAL,x
  beq @shot
  lda SHIP_FACTION,x
  bne @notFlak
  jmp LaunchShell
@notFlak:
  cmp #SP_MINE
  bne @noShot                      ; a cloak or a jump takes the shot's place
  jsr LayMine
@shot:
  lda PLAN_WEAPON,x
  bne LaunchTorpedo
  lda #1
  sta FIRING,x
  stz BEAM_DX,x
  stz BEAM_DY,x
@noShot:
  rts

; LaunchTorpedo - from where ship X starts, through its aim, 3.75 pixels a tick.
LaunchTorpedo:
  jsr AimVector
  jsr ScaleDir
  php
  ldx TI
  plp
  bne @aimed
  rts
@aimed:
  jsr DirLength
  lda DIRX
  jsr TorpSpeed
  ldx TI
  lda QUOT
  sta TORP_VX_LO,x
  lda QUOT+1
  sta TORP_VX_HI,x
  lda DIRY
  jsr TorpSpeed
  ldx TI
  lda QUOT
  sta TORP_VY_LO,x
  lda QUOT+1
  sta TORP_VY_HI,x
  lda POS_X_HI,x
  sta TORP_X_HI,x
  stz TORP_X_LO,x
  lda POS_Y_HI,x
  sta TORP_Y_HI,x
  stz TORP_Y_LO,x
  lda #1
  sta TORP_ON,x
  sta ANY
  rts

; TorpSpeed - QUOT = A (a signed direction part) * 960 / LEN, signed.
TorpSpeed:
  sta MA
  jsr Abs8
  ldx #TORP_SPEED
  jsr Mul8
  asl PROD
  rol PROD+1
  asl PROD
  rol PROD+1
  lda PROD
  sta DIVIDEND
  lda PROD+1
  sta DIVIDEND+1
  lda LEN
  sta DIVISOR
  jsr Div16
  lda MA
  bpl @done
  lda QUOT
  eor #$FF
  clc
  adc #1
  sta QUOT
  lda QUOT+1
  eor #$FF
  adc #0
  sta QUOT+1
@done:
  rts

; AimVector - SD_DX, SD_DY = ship X's aim minus its position. Keeps X.
AimVector:
  lda AIM_X,x
  sec
  sbc POS_X_HI,x
  sta SD_DX
  lda #0
  sbc #0
  sta SD_DX+1
  lda AIM_Y,x
  sec
  sbc POS_Y_HI,x
  sta SD_DY
  lda #0
  sbc #0
  sta SD_DY+1
  rts

; --- Each tick ---

MoveShips:
  lda TICK
  cmp #TICKS
  bcs @done
  ldx N_SHIPS
  dex
@ship:
  lda SHIP_ALIVE,x
  beq @next
  lda POS_X_LO,x
  clc
  adc VEL_X_LO,x
  sta POS_X_LO,x
  lda POS_X_HI,x
  adc VEL_X_HI,x
  sta POS_X_HI,x
  lda POS_Y_LO,x
  clc
  adc VEL_Y_LO,x
  sta POS_Y_LO,x
  lda POS_Y_HI,x
  adc VEL_Y_HI,x
  sta POS_Y_HI,x
@next:
  dex
  bpl @ship
@done:
  rts

MoveTorpedoes:
  ldx N_SHIPS
  dex
@torp:
  lda TORP_FLASH,x
  beq @noFlash
  dec TORP_FLASH,x
@noFlash:
  lda TORP_ON,x
  beq @next
  lda TORP_X_LO,x
  clc
  adc TORP_VX_LO,x
  sta TORP_X_LO,x
  lda TORP_X_HI,x
  adc TORP_VX_HI,x
  sta TORP_X_HI,x
  lda TORP_Y_LO,x
  clc
  adc TORP_VY_LO,x
  sta TORP_Y_LO,x
  lda TORP_Y_HI,x
  adc TORP_VY_HI,x
  sta TORP_Y_HI,x
  lda TORP_ON,x
  cmp #TORP_SHELL
  beq @next                        ; a shell only bursts where it's aimed
  lda TORP_X_HI,x                  ; off the board?
  cmp #BOARD_X
  bcc @off
  cmp #BOARD_RIGHT + 1
  bcs @off
  lda TORP_Y_HI,x
  cmp #BOARD_Y
  bcc @off
  cmp #BOARD_BOTTOM + 1
  bcs @off
  stx TI
  jsr TorpedoContact
  ldx TI
  bra @next
@off:
  stz TORP_ON,x
@next:
  dex
  bpl @torp
  rts

; TorpedoContact - torpedo TI against every other ship.
TorpedoContact:
  stz TJ
@ship:
  ldy TJ
  cpy TI
  beq @next
  lda ON_FIELD,y
  beq @next
  ldx TI
  lda TORP_X_HI,x
  sec
  sbc POS_X_HI,y
  bcs @dx
  eor #$FF
  inc a
@dx:
  cmp #11
  bcs @next
  sta T0
  lda TORP_Y_HI,x
  sec
  sbc POS_Y_HI,y
  bcs @dy
  eor #$FF
  inc a
@dy:
  cmp #11
  bcs @next
  tay
  lda SqTab,y
  ldy T0
  clc
  adc SqTab,y
  cmp #TORP_REACH_SQ
  bcs @next
  ; a hit: its faction's torpedo damage, all at once
  stz TORP_ON,x
  lda #8
  sta TORP_FLASH,x
  ldy SHIP_FACTION,x
  lda TorpedoDamage,y
  ldy TJ
  jsr HitShip
  jmp SndTorpHit
@next:
  inc TJ
  lda TJ
  cmp N_SHIPS
  bne @ship
  rts

BurnLasers:
  lda TICK
  cmp #CHARGE_TICKS
  bcc @done
  cmp #TICKS
  bcs @done
  ldx #3                           ; with several beams up, redraw them less often
  ldy BEAM_N
  cpy #3
  bcc @often
  ldx #7
@often:
  stx T0
  and T0
  bne @noDraw
  lda #1
  sta REDRAW
@noDraw:
  stz ANY
  stz TI
@ship:
  ldx TI
  lda FIRING,x
  beq @next
  lda SHIP_ALIVE,x
  beq @next
  inc ANY
  jsr LaserShip
@next:
  inc TI
  lda TI
  cmp N_SHIPS
  bne @ship
  lda ANY
  sta BEAM_N
  bne @on
  jmp SndLaserOff
@on:
  jmp SndLaserOn
@done:
  rts

; LaserShip - ship X's beam: its line, the first ship on it, and the burn.
LaserShip:
  stx SHOOT
  jsr AimVector
  ; within a few pixels of its aim it keeps the last direction
  lda SD_DX
  jsr Abs8
  sta T0
  lda SD_DY
  jsr Abs8
  clc
  adc T0
  cmp #3
  bcc @keep
  jsr ScaleDir
  ldx SHOOT
  lda DIRX
  sta BEAM_DX,x
  lda DIRY
  sta BEAM_DY,x
  bra @aimed
@keep:
  ldx SHOOT
  lda BEAM_DX,x
  sta DIRX
  lda BEAM_DY,x
  sta DIRY
@aimed:
  jsr DirLength
  lda LEN
  bne @line
  rts
@line:
  lda #$FF
  sta BEST
  sta BESTDOT
  lda #$7F
  sta BESTDOT+1
  stz TJ
@target:
  ldy TJ
  cpy SHOOT
  beq @nextT
  lda ON_FIELD,y
  beq @nextT
  jsr TestTarget
@nextT:
  inc TJ
  lda TJ
  cmp N_SHIPS
  bne @target
  ; a change of target redraws the beam at once
  ldx SHOOT
  lda BEST
  cmp BEAM_TGT,x
  beq @same
  sta BEAM_TGT,x
  lda #1
  sta REDRAW
@same:
  lda BEST
  cmp #$FF
  beq @done
  ; how far along the line, in hexes
  lda BESTDOT
  sta DIVIDEND
  lda BESTDOT+1
  sta DIVIDEND+1
  lda LEN
  sta DIVISOR
  jsr Div16
  lda QUOT
  sta DIVIDEND
  lda QUOT+1
  sta DIVIDEND+1
  lda #HEX_PIXELS
  sta DIVISOR
  jsr Div16
  lda QUOT
  cmp #12
  bcc @near
  lda #12
@near:
  tax
  ldy BEST
  lda SHIP_HP_LO,y
  sec
  sbc BurnLo,x
  sta SHIP_HP_LO,y
  lda SHIP_HP_HI,y
  sbc BurnHi,x
  bcs @alive
  lda #0
  sta SHIP_HP_LO,y
@alive:
  sta SHIP_HP_HI,y
  lda TICK                         ; a burn is heard every quarter of the turn
  and #15
  bne @heard
  jsr SndHit
@heard:
  lda CLOAKED,y
  beq @done
  jmp SpotShip                     ; a burn gives a cloaked ship away
@done:
  rts

; ThrustSound - engines, if any ship is going anywhere.
ThrustSound:
  ldx N_SHIPS
  dex
@ship:
  lda SHIP_ALIVE,x
  beq @next
  lda JUMPING,x
  bne @next
  lda PLAN_C,x
  cmp SHIP_C,x
  bne @moving
  lda PLAN_R,x
  cmp SHIP_R,x
  bne @moving
@next:
  dex
  bpl @ship
  rts
@moving:
  jmp SndThrust

; TestTarget - is ship Y on SHOOT's line, and nearer than BEST?
TestTarget:
  ldx SHOOT
  lda POS_X_HI,y
  sec
  sbc POS_X_HI,x
  sta VX
  lda #0
  sbc #0
  sta VX+1
  lda POS_Y_HI,y
  sec
  sbc POS_Y_HI,x
  sta VY
  lda #0
  sbc #0
  sta VY+1
  jsr LineTest
  bcc @no
  lda DOT
  cmp BESTDOT
  lda DOT+1
  sbc BESTDOT+1
  bcs @no
  lda DOT
  sta BESTDOT
  lda DOT+1
  sta BESTDOT+1
  lda TJ
  sta BEST
@no:
  rts

; (the CPU's code in its own bank uses this too)
.segment "CART"

; LineTest - carry set if a ship at (VX, VY) from the start of the line
; (DIRX, DIRY), length LEN, is ahead and touching it. Leaves DOT, how far along.
LineTest:
  lda DIRX
  sta MA
  lda VX
  sta MB
  lda VX+1
  sta MB+1
  jsr SMul
  lda PROD
  sta DOT
  lda PROD+1
  sta DOT+1
  lda DIRY
  sta MA
  lda VY
  sta MB
  lda VY+1
  sta MB+1
  jsr SMul
  lda DOT
  clc
  adc PROD
  sta DOT
  lda DOT+1
  adc PROD+1
  sta DOT+1
  bmi @no                          ; behind
  ora DOT
  beq @no
  lda DIRX
  sta MA
  lda VY
  sta MB
  lda VY+1
  sta MB+1
  jsr SMul
  lda PROD
  sta CROSS
  lda PROD+1
  sta CROSS+1
  lda DIRY
  sta MA
  lda VX
  sta MB
  lda VX+1
  sta MB+1
  jsr SMul
  lda CROSS
  sec
  sbc PROD
  sta CROSS
  lda CROSS+1
  sbc PROD+1
  sta CROSS+1
  bpl @abs
  lda CROSS
  eor #$FF
  clc
  adc #1
  sta CROSS
  lda CROSS+1
  eor #$FF
  adc #0
  sta CROSS+1
@abs:
  ; touching if |cross| / LEN < SHIP_REACH, that is |cross| / 8 < LEN
  lsr CROSS+1
  ror CROSS
  lsr CROSS+1
  ror CROSS
  lsr CROSS+1
  ror CROSS
  lda CROSS+1
  bne @no
  lda CROSS
  cmp LEN
  bcs @no
  sec
  rts
@no:
  clc
  rts


.segment "BANK00"

; CheckWrecks - ships out of hull blow up; explosions run their course.
CheckWrecks:
  ldx N_SHIPS
  dex
@ship:
  lda SHIP_ALIVE,x
  beq @burning
  lda SHIP_HP_HI,x
  bne @burning
  stz SHIP_ALIVE,x
  stz ON_FIELD,x
  stz FIRING,x
  lda #1
  sta EXPL_T,x
  sta REDRAW
  phx
  jsr SndBoom
  plx
  bra @next
@burning:
  lda EXPL_T,x
  beq @next
  inc EXPL_T,x
  lda EXPL_T,x
  cmp #26
  bcc @next
  stz EXPL_T,x
@next:
  dex
  bpl @ship
  rts

; DrawBeams - redraw every beam when one has moved.
DrawBeams:
  lda REDRAW
  beq @done
  stz REDRAW
  jsr CanvasBegin
  lda TICK
  cmp #TICKS
  bcs @show
  stz TI
@ship:
  ldx TI
  lda FIRING,x
  beq @next
  lda SHIP_ALIVE,x
  beq @next
  jsr DrawBeam
@next:
  inc TI
  lda TI
  cmp N_SHIPS
  bne @ship
@show:
  jsr DrawFx
  jmp CanvasFlush
@done:
  rts

; DrawBeam - ship X's line, to the ship it stops on or the board's edge.
DrawBeam:
  lda POS_X_HI,x
  sta LX
  lda POS_Y_HI,x
  sta LY
  jsr SetPen
  stz LTGT
  ldy BEAM_TGT,x
  cpy #$FF
  beq @free
  lda POS_X_HI,y
  sta LTX
  lda POS_Y_HI,y
  sta LTY
  inc LTGT
@free:
  ldy #1
  lda BEAM_DX,x
  bpl @xPos
  ldy #$FF
  eor #$FF
  inc a
@xPos:
  sty LSX
  sta LAX
  ldy #1
  lda BEAM_DY,x
  bpl @yPos
  ldy #$FF
  eor #$FF
  inc a
@yPos:
  sty LSY
  sta LAY
  ora LAX
  beq @end
  stz LSTEP
  lda LAX
  cmp LAY
  bcc @steep
  lsr a
  sta LERR
@wide:
  lda LX
  clc
  adc LSX
  sta LX
  lda LERR
  sec
  sbc LAY
  sta LERR
  bpl @wideP
  clc
  adc LAX
  sta LERR
  lda LY
  clc
  adc LSY
  sta LY
@wideP:
  jsr BeamPixel
  bcc @wide
@end:
  rts
@steep:
  lda LAY
  lsr a
  sta LERR
@tall:
  lda LY
  clc
  adc LSY
  sta LY
  lda LERR
  sec
  sbc LAX
  sta LERR
  bpl @tallP
  clc
  adc LAY
  sta LERR
  lda LX
  clc
  adc LSX
  sta LX
@tallP:
  jsr BeamPixel
  bcc @tall
  rts

; BeamPixel - plot (LX, LY); carry set when the beam ends here.
BeamPixel:
  lda LX
  cmp #BOARD_X
  bcc @stop
  cmp #BOARD_RIGHT + 1
  bcs @stop
  sta PX
  lda LY
  cmp #BOARD_Y
  bcc @stop
  cmp #BOARD_BOTTOM + 1
  bcs @stop
  sta PY
  lda LTGT
  beq @plot
  lda LX
  sec
  sbc LTX
  bcs @dx
  eor #$FF
  inc a
@dx:
  cmp #9
  bcs @plot
  sta T0
  lda LY
  sec
  sbc LTY
  bcs @dy
  eor #$FF
  inc a
@dy:
  cmp #9
  bcs @plot
  tax
  lda SqTab,x
  ldx T0
  clc
  adc SqTab,x
  cmp #BEAM_STOP_SQ
  bcc @stop
@plot:
  jsr CanvasPlot
  inc LSTEP
  beq @stop
  clc
  rts
@stop:
  sec
  rts

; DrawSprites - ships, torpedoes and explosions where they are now.
DrawSprites:
  stz TI
@ship:
  ldx TI
  lda POS_X_HI,x
  sta HX
  lda POS_Y_HI,x
  sta HY
  lda SHIP_ALIVE,x
  beq @noShip
  lda JUMPING,x
  bne @noShip
  jsr ShowShip
  bra @torp
@noShip:
  jsr HideSprite
@torp:
  ; torpedo slot: flying, flashing where it hit, or hidden
  ldx TI
  lda TORP_X_HI,x
  sta HX
  lda TORP_Y_HI,x
  sta HY
  lda TORP_ON,x
  bne @flying
  lda TORP_FLASH,x
  bne @flash
  lda SLOT_TORP_HIDE,x
  tax
  jsr HideSprite
  bra @expl
@flying:
  ldy #PAT_TORPEDO
  cmp #TORP_SHELL
  bne @pattern
  ldy #PAT_SHELL
@pattern:
  sty T0
  lda SHIP_ROW,x
  ora #SPR_FRONT
  tay
  lda SLOT_TORP_HIDE,x
  tax
  lda T0
  jsr PlaceSprite
  bra @expl
@flash:
  lda SLOT_TORP_HIDE,x
  tax
  lda #PAT_EXPL1
  ldy #ROW_ORANGE | SPR_FRONT
  jsr PlaceSprite
@expl:
  ldx TI
  lda POS_X_HI,x
  sta HX
  lda POS_Y_HI,x
  sta HY
  lda EXPL_T,x
  bne @burn
  lda SLOT_EXPL_HIDE,x
  tax
  jsr HideSprite
  bra @next
@burn:
  ldy #PAT_EXPL1
  cmp #7
  bcc @frame
  ldy #PAT_EXPL2
  cmp #15
  bcc @frame
  ldy #PAT_EXPL3
@frame:
  sty T0
  lda SLOT_EXPL_HIDE,x
  tax
  lda T0
  ldy #ROW_ORANGE | SPR_FRONT
  jsr PlaceSprite
@next:
  inc TI
  lda TI
  cmp N_SHIPS
  beq @upload
  jmp @ship
@upload:
  jsr ShowMines
  jsr ShowFx
  jmp UploadSprites

; DrawHulls - the panel's bars, a few times a second, when they've changed.
DrawHulls:
  lda TICK
  and #3
  cmp #2
  bne @done
  ldx #0
@ship:
  lda SHIP_HP_HI,x
  cmp HP_SHOWN,x
  beq @next
  jsr DrawHpLine
@next:
  inx
  cpx N_SHIPS
  bne @ship
@done:
  rts
