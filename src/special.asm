; =============================================================================
;   special.asm - each faction's special ability
; =============================================================================
;   The app's rules. A special recharges for some turns once it's used.
;     Vanguard, flak shell: in place of the shot, lobbed at a hex up to 5 away.
;       It bursts as ships stop, 45 to every other ship within a hex.
;     Raider, mine: goes with the shot, dropped where the ship starts. Only its
;       owner sees it. It arms halfway through the turn it's dropped, and goes
;       off for 25 on any other ship that comes within a hex. 3 at most.
;     Swarm, cloak: in place of the shot. Unseen from now until the next turn
;       plays, so the others plan knowing only where it was last seen.
;     Wraith, jump: in place of the move and the shot. Gone until halfway
;       through the turn, it lands up to 6 hexes away with a shockwave: 20 to a
;       ship next to it, 40 to one it lands on, and 20 to itself for that.
; =============================================================================

.segment "CART"

RechargeTurns:
  .byte 1, 3, 1, 5

SqLo:
.repeat AREA_REACH + 1, I
  .byte <(I * I)
.endrepeat
SqHi:
.repeat AREA_REACH + 1, I
  .byte >(I * I)
.endrepeat

SpecialNames:
  .word TxtSpFlak, TxtSpMine, TxtSpCloak, TxtSpJump
ChoiceTexts:
  .word TxtLaser, TxtTorpedo, TxtLaserMine, TxtTorpMine
  .word TxtFlakShell, TxtCloak, TxtJump
ChoiceOf:                          ; a special's line in ChoiceTexts (mine aside)
  .byte 4, 0, 5, 6
TipName:
  .word TxtFlakShell, TxtMine, TxtCloak, TxtJump
TipA:
  .word TxtTipFlak1, TxtTipMine1, TxtTipCloak1, TxtTipJump1
TipB:
  .word TxtTipFlak2, TxtTipMine2, TxtTipCloak2, TxtTipJump2

TxtSpFlak:     .asciiz "FLAK"
TxtSpMine:     .asciiz "MINE"
TxtSpCloak:    .asciiz "CLOAK"
TxtSpJump:     .asciiz "JUMP"
TxtReady:      .asciiz " READY"
TxtIn:         .asciiz " IN "
TxtFlakShell:  .asciiz "FLAK SHELL"
TxtMine:       .asciiz "MINE"
TxtCloak:      .asciiz "CLOAK"
TxtJump:       .asciiz "JUMP"
TxtLaserMine:  .asciiz "LASER+MINE"
TxtTorpMine:   .asciiz "TORP+MINE"
TxtJumpWhere:  .asciiz "JUMP WHERE?"
TxtUpTo6:      .asciiz "UP TO 6 HEX"
TxtShellWhere: .asciiz "SHELL WHERE"
TxtUpTo5:      .asciiz "UP TO 5 HEX"
TxtTipFlak1:   .asciiz "BURST OF 45"
TxtTipFlak2:   .asciiz "5 HEX RANGE"
TxtTipMine1:   .asciiz "DROP UNSEEN"
TxtTipMine2:   .asciiz "BLAST OF 25"
TxtTipCloak1:  .asciiz "UNSEEN FOR"
TxtTipCloak2:  .asciiz "ONE TURN"
TxtTipJump1:   .asciiz "WARP 6 HEX"
TxtTipJump2:   .asciiz "SHOCK OF 20"

; --- What's picked ---

; PickedSpecial - A = the special ship PLAYER has picked, or $FF. Keeps Y.
PickedSpecial:
  ldx PLAYER
  lda PLAN_SPECIAL,x
  beq @none
  lda SHIP_FACTION,x
  rts
@none:
  lda #$FF
  rts

; IsJump, IsFlak - Z set if that's what ship PLAYER has picked. Keep Y.
IsJump:
  jsr PickedSpecial
  cmp #SP_JUMP
  rts

IsFlak:
  jsr PickedSpecial
  cmp #SP_FLAK
  rts

; NeedsAim - carry set if ship PLAYER's plan needs a hex to aim at.
NeedsAim:
  jsr PickedSpecial
  cmp #SP_CLOAK
  beq @no
  cmp #SP_JUMP
  beq @no
  sec
  rts
@no:
  clc
  rts

; CanView - carry set if ship X's hidden things show right now. Keeps X, Y.
CanView:
  cpx VIEWER
  beq @yes
  lda VIEWER
  cmp #VIEW_ALL
  beq @yes
  clc
  rts
@yes:
  sec
  rts

; --- The panel ---

; DrawSpecial - ship PLAYER's special: ready, or how long until it is.
DrawSpecial:
  ldx PLAYER
  lda SHIP_INK,x
  ldy SPECIAL_WAIT,x
  beq @ink
  lda #INK_GRAY
@ink:
  sta TXT_INK
  jsr LineStart
  ldx PLAYER
  lda SHIP_FACTION,x
  asl a
  tay
  lda SpecialNames+1,y
  pha
  lda SpecialNames,y
  tax
  ply
  jsr LineStr
  ldx PLAYER
  lda SPECIAL_WAIT,x
  bne @wait
  ldx #<TxtReady
  ldy #>TxtReady
  jsr LineStr
  bra @show
@wait:
  ldx #<TxtIn
  ldy #>TxtIn
  jsr LineStr
  ldx PLAYER
  lda SPECIAL_WAIT,x
  jsr LineNum
@show:
  lda #ROW_MSG7
  jmp LineShow

; DrawChoice - what ship PLAYER will do this turn, on the weapon row.
DrawChoice:
  ldx PLAYER
  lda SHIP_INK,x
  sta TXT_INK
  lda PLAN_SPECIAL,x
  bne @special
  lda PLAN_WEAPON,x
  bra @text
@special:
  lda SHIP_FACTION,x
  cmp #SP_MINE
  bne @other
  lda PLAN_WEAPON,x
  clc
  adc #2
  bra @text
@other:
  tay
  lda ChoiceOf,y
@text:
  asl a
  tay
  lda ChoiceTexts+1,y
  pha
  lda ChoiceTexts,y
  tax
  ply
  lda #ROW_MSG5
  jmp Print

; DrawTip - the title screen: what the selected seat's special does.
DrawTip:
  lda SEL
  cmp #2
  bcc @seat
  lda #ROW_TIP1
  jsr PanelClear
  lda #ROW_TIP2
  jsr PanelClear
  lda #ROW_TIP3
  jmp PanelClear
@seat:
  tax
  lda SHIP_INK,x
  sta TXT_INK
  lda SHIP_FACTION,x
  asl a
  sta MN_I
  tay
  lda TipName+1,y
  pha
  lda TipName,y
  tax
  ply
  lda #ROW_TIP1
  jsr Print
  lda #INK_GRAY
  sta TXT_INK
  ldy MN_I
  lda TipA+1,y
  pha
  lda TipA,y
  tax
  ply
  lda #ROW_TIP2
  jsr Print
  ldy MN_I
  lda TipB+1,y
  pha
  lda TipB,y
  tax
  ply
  lda #ROW_TIP3
  jmp Print

; --- Sprites for what's hidden ---

; ShowMines - the mines the viewer may see.
ShowMines:
  ldy #NUM_MINES - 1
@mine:
  lda MINE_OWNER,y
  beq @hide
  dec a
  tax
  jsr CanView
  bcc @hide
  lda MINE_X,y
  sta HX
  lda MINE_Y,y
  sta HY
  phy
  lda SHIP_ROW,x
  ora #SPR_FRONT
  pha
  tya
  clc
  adc #SLOT_MINE
  tax
  ply
  lda #PAT_MINE
  jsr PlaceSprite
  ply
  bra @next
@hide:
  tya
  clc
  adc #SLOT_MINE
  tax
  jsr HideSprite
@next:
  dey
  bpl @mine
  rts

; ShowSeen - a marker where each cloaked ship was last seen.
ShowSeen:
  ldx #NUM_SHIPS - 1
@ship:
  lda SHIP_ALIVE,x
  beq @hide
  lda CLOAKED,x
  beq @hide
  phx
  ldy SEEN_R,x
  lda SEEN_C,x
  tax
  jsr HexCenter
  plx
  phx
  lda SHIP_ROW,x
  ora #SPR_FRONT
  tay
  txa
  clc
  adc #SLOT_SEEN
  tax
  lda #PAT_SEEN
  jsr PlaceSprite
  plx
  bra @next
@hide:
  phx
  txa
  clc
  adc #SLOT_SEEN
  tax
  jsr HideSprite
  plx
@next:
  dex
  bpl @ship
  rts

HideSeen:
  ldx #SLOT_SEEN
  jsr HideSprite
  ldx #SLOT_SEEN + 1
  jmp HideSprite

; ResetSpecials - nothing used, nothing on the board.
ResetSpecials:
  ldx #NUM_SHIPS - 1
@ship:
  stz SPECIAL_WAIT,x
  stz PLAN_SPECIAL,x
  stz CLOAKED,x
  stz JUMPING,x
  dex
  bpl @ship
  ldx #NUM_MINES - 1
@mine:
  stz MINE_OWNER,x
  dex
  bpl @mine
  ldx #NUM_FX - 1
@fx:
  stz FX_T,x
  dex
  bpl @fx
  jsr ShowMines
  jsr ShowFx
  jmp HideSeen

; --- Starting a turn ---

; ArmOldMines - mines already down are armed from the first tick.
ArmOldMines:
  ldx #NUM_MINES - 1
@mine:
  stz MINE_ARM,x
  dex
  bpl @mine
  rts

; StartSpecial - ship X: recharging, and a cloak if it's cloaking. Keeps X.
StartSpecial:
  stz CLOAKED,x
  lda PLAN_SPECIAL,x
  bne @used
  lda SPECIAL_WAIT,x
  beq @done
  dec SPECIAL_WAIT,x
@done:
  rts
@used:
  ldy SHIP_FACTION,x
  lda RechargeTurns,y
  sta SPECIAL_WAIT,x
  cpy #SP_CLOAK
  bne @done
  lda #1
  sta CLOAKED,x
  lda SHIP_C,x
  sta SEEN_C,x
  lda SHIP_R,x
  sta SEEN_R,x
  jsr ShipCenter
  lda HX
  sta AREA_X
  lda HY
  sta AREA_Y
  txa
  inc a
  jsr AddFx
  phx
  jsr SndCloak
  plx
  rts

; StartJump - ship X vanishes; its aim point becomes where it lands. Keeps X.
StartJump:
  stz VEL_X_LO,x
  stz VEL_X_HI,x
  stz VEL_Y_LO,x
  stz VEL_Y_HI,x
  lda PLAN_C,x
  sta AIM_C,x
  lda PLAN_R,x
  sta AIM_R,x
  lda #1
  sta JUMPING,x
  stz ON_FIELD,x
  lda POS_X_HI,x
  sta AREA_X
  lda POS_Y_HI,x
  sta AREA_Y
  txa
  inc a
  jsr AddFx
  phx
  jsr SndWarp
  plx
  rts

; DeltaTimes4 - T1:T0 = (A - Y) * 4, signed: a whole-turn glide's velocity.
DeltaTimes4:
  sty T0
  sec
  sbc T0
  sta T0
  lda #0
  sbc #0
  sta T1
  asl T0
  rol T1
  asl T0
  rol T1
  rts

; LaunchShell - ship X's flak shell, reaching its aim as the turn ends. It flies
; in the ship's torpedo slot. Keeps X.
LaunchShell:
  lda AIM_X,x
  ldy POS_X_HI,x
  jsr DeltaTimes4
  lda T0
  sta TORP_VX_LO,x
  lda T1
  sta TORP_VX_HI,x
  lda AIM_Y,x
  ldy POS_Y_HI,x
  jsr DeltaTimes4
  lda T0
  sta TORP_VY_LO,x
  lda T1
  sta TORP_VY_HI,x
  lda POS_X_HI,x
  sta TORP_X_HI,x
  stz TORP_X_LO,x
  lda POS_Y_HI,x
  sta TORP_Y_HI,x
  stz TORP_Y_LO,x
  lda #TORP_SHELL
  sta TORP_ON,x
  sta ANY
  rts

; OwnMineHere - carry set if one of ship X's mines lies on its hex. Keeps X.
OwnMineHere:
  txa
  inc a
  sta MN_OWNER
  ldy #NUM_MINES - 1
@mine:
  lda MINE_OWNER,y
  cmp MN_OWNER
  bne @next
  lda MINE_C,y
  cmp SHIP_C,x
  bne @next
  lda MINE_R,y
  cmp SHIP_R,x
  beq @yes
@next:
  dey
  bpl @mine
  clc
  rts
@yes:
  sec
  rts

; LayMine - ship X drops a mine where it starts, clearing its oldest past the
; limit. Keeps X.
LayMine:
  jsr OwnMineHere
  bcs @done
  stz MN_COUNT
  lda #$FF
  sta MN_AGE
  ldy #NUM_MINES - 1
@scan:
  lda MINE_OWNER,y
  bne @used
  sty MN_FREE
  bra @next
@used:
  cmp MN_OWNER
  bne @next
  inc MN_COUNT
  lda MINE_TURN,y
  cmp MN_AGE
  bcs @next
  sta MN_AGE
  sty MN_OLD
@next:
  dey
  bpl @scan
  ldy MN_FREE
  lda MN_COUNT
  cmp #MINE_LIMIT
  bcc @place
  ldy MN_OLD
@place:
  lda MN_OWNER
  sta MINE_OWNER,y
  lda SHIP_C,x
  sta MINE_C,y
  lda SHIP_R,x
  sta MINE_R,y
  lda POS_X_HI,x
  sta MINE_X,y
  lda POS_Y_HI,x
  sta MINE_Y,y
  lda #HALF_TURN
  sta MINE_ARM,y
  lda TURN
  sta MINE_TURN,y
  jsr CanView                      ; only its owner hears it drop
  bcc @done
  jsr SndMine
@done:
  rts

; --- Hits ---

; AreaTest - carry set if ship Y is within a blast's reach of (AREA_X, AREA_Y),
; with DSQ its distance squared. Keeps Y.
AreaTest:
  lda POS_X_HI,y
  sec
  sbc AREA_X
  bcs @dx
  eor #$FF
  inc a
@dx:
  cmp #AREA_REACH + 1
  bcs @no
  tax
  lda SqLo,x
  sta DSQ
  lda SqHi,x
  sta DSQ+1
  lda POS_Y_HI,y
  sec
  sbc AREA_Y
  bcs @dy
  eor #$FF
  inc a
@dy:
  cmp #AREA_REACH + 1
  bcs @no
  tax
  lda SqLo,x
  clc
  adc DSQ
  sta DSQ
  lda SqHi,x
  adc DSQ+1
  sta DSQ+1
  lda DSQ
  cmp #<(AREA_REACH_SQ + 1)
  lda DSQ+1
  sbc #>(AREA_REACH_SQ + 1)
  bcs @no
  sec
  rts
@no:
  clc
  rts

; HitShip - A whole points off ship Y. A cloaked ship is seen where it's hit.
; Keeps Y.
HitShip:
  sta T0
  lda SHIP_HP_HI,y
  sec
  sbc T0
  bcs @left
  lda #0
  sta SHIP_HP_LO,y
@left:
  sta SHIP_HP_HI,y
  lda CLOAKED,y
  beq @done
  jmp SpotShip
@done:
  rts

; SpotShip - ship Y is last seen on the hex under it. Keeps Y.
SpotShip:
  lda POS_Y_HI,y
  sec
  sbc #BOARD_Y + 3
  bcs @row
  lda #0
@row:
  sta DIVIDEND
  stz DIVIDEND+1
  lda #15
  sta DIVISOR
  jsr Div16
  lda QUOT
  cmp #ROWS
  bcc @rowOk
  lda #ROWS - 1
@rowOk:
  sta SEEN_R,y
  and #1
  bne @odd
  lda #10                          ; even rows sit half a hex right
@odd:
  and #10
  sta T0
  lda POS_X_HI,y
  sec
  sbc #BOARD_X
  bcc @left
  sec
  sbc T0
  bcs @col
@left:
  lda #0
@col:
  sta DIVIDEND
  stz DIVIDEND+1
  lda #HEX_PIXELS
  sta DIVISOR
  jsr Div16
  lda SEEN_R,y
  jsr RowLen
  dec a
  cmp QUOT
  bcc @last
  lda QUOT
@last:
  sta SEEN_C,y
  rts

; CheckMines - armed mines against the ships that touch them.
CheckMines:
  lda TICK
  cmp #TICKS
  bcs @done
  ldx #NUM_MINES - 1
@mine:
  lda MINE_OWNER,x
  beq @next
  dec a
  sta MN_OWNER
  lda TICK
  cmp MINE_ARM,x
  bcc @next
  stx MN_I
  lda MINE_X,x
  sta AREA_X
  lda MINE_Y,x
  sta AREA_Y
  stz MN_HIT
  ldy #NUM_SHIPS - 1
@ship:
  cpy MN_OWNER
  beq @nextShip
  lda ON_FIELD,y
  beq @nextShip
  jsr AreaTest
  bcc @nextShip
  lda #MINE_DAMAGE
  jsr HitShip
  inc MN_HIT
@nextShip:
  dey
  bpl @ship
  ldx MN_I
  lda MN_HIT
  beq @next
  stz MINE_OWNER,x
  lda MN_OWNER
  inc a
  jsr AddBlast
  jsr SndBlast
  ldx MN_I
@next:
  dex
  bpl @mine
@done:
  rts

; LandJumps - halfway through the turn, jumping ships arrive together.
LandJumps:
  lda TICK
  cmp #HALF_TURN
  bne @done
  ldx #NUM_SHIPS - 1
@arrive:
  lda JUMPING,x
  beq @nextArrive
  lda #2
  sta JUMPING,x
  lda #1
  sta ON_FIELD,x
  lda AIM_X,x
  sta POS_X_HI,x
  stz POS_X_LO,x
  lda AIM_Y,x
  sta POS_Y_HI,x
  stz POS_Y_LO,x
@nextArrive:
  dex
  bpl @arrive
  ldx #NUM_SHIPS - 1
@ship:
  lda JUMPING,x
  beq @next
  stz JUMPING,x
  stx MN_I
  lda POS_X_HI,x
  sta AREA_X
  lda POS_Y_HI,x
  sta AREA_Y
  txa
  inc a
  jsr AddBlast
  jsr SndWarp
  ldy #NUM_SHIPS - 1
@other:
  cpy MN_I
  beq @nextOther
  lda ON_FIELD,y
  beq @nextOther
  jsr AreaTest
  bcc @nextOther
  lda DSQ+1                        ; under 256: 16 pixels, the ships overlap
  bne @shock
  lda #RAM_DAMAGE
  jsr HitShip
  phy
  ldy MN_I
  lda #RAM_RECOIL
  jsr HitShip
  ply
  bra @nextOther
@shock:
  lda #SHOCK_DAMAGE
  jsr HitShip
@nextOther:
  dey
  bpl @other
  ldx MN_I
@next:
  dex
  bpl @ship
@done:
  rts

; FlakBursts - as ships stop, every shell bursts on its hex.
FlakBursts:
  lda TICK
  cmp #LAST_TICK
  bne @done
  ldx #NUM_SHIPS - 1
@ship:
  lda TORP_ON,x
  cmp #TORP_SHELL
  bne @next
  stz TORP_ON,x
  stx MN_I
  lda AIM_X,x
  sta AREA_X
  lda AIM_Y,x
  sta AREA_Y
  txa
  inc a
  jsr AddBlast
  jsr SndBlast
  ldy #NUM_SHIPS - 1
@other:
  cpy MN_I
  beq @nextOther
  lda ON_FIELD,y
  beq @nextOther
  jsr AreaTest
  bcc @nextOther
  lda #FLAK_DAMAGE
  jsr HitShip
@nextOther:
  dey
  bpl @other
  ldx MN_I
@next:
  dex
  bpl @ship
@done:
  rts

; --- Blast rings, drawn on the canvas with the beams ---

; AddBlast - a ring with a fireball in it at (AREA_X, AREA_Y), in the color of
; ship A - 1. Keeps X, Y.
AddBlast:
  pha
  lda #1
  sta FX_KIND
  pla
  bra AddRing

; AddFx - just a ring. Keeps X, Y.
AddFx:
  stz FX_KIND
AddRing:
  phx
  pha
  ldx #NUM_FX - 1
@find:
  lda FX_T,x
  beq @got
  dex
  bpl @find
  ldx #0
@got:
  pla
  sta FX_INK,x
  lda AREA_X
  sta FX_X,x
  lda AREA_Y
  sta FX_Y,x
  lda FX_KIND
  sta FX_BOOM,x
  lda #1
  sta FX_T,x
  sta REDRAW
  plx
  rts

; ShowFx - the fireball sprites.
ShowFx:
  ldx #NUM_FX - 1
@fx:
  phx
  lda FX_T,x
  beq @hide
  ldy FX_BOOM,x
  beq @hide
  ldy #PAT_EXPL1
  cmp #FX_STEP
  bcc @frame
  ldy #PAT_EXPL2
  cmp #FX_STEP * 2
  bcc @frame
  ldy #PAT_EXPL3
@frame:
  sty T0
  lda FX_X,x
  sta HX
  lda FX_Y,x
  sta HY
  txa
  clc
  adc #SLOT_FX
  tax
  lda T0
  ldy #ROW_ORANGE | SPR_FRONT
  jsr PlaceSprite
  bra @next
@hide:
  txa
  clc
  adc #SLOT_FX
  tax
  jsr HideSprite
@next:
  plx
  dex
  bpl @fx
  rts

; UpdateFx - rings grow through three sizes, then go.
UpdateFx:
  ldx #NUM_FX - 1
@fx:
  lda FX_T,x
  beq @next
  inc a
  sta FX_T,x
  cmp #FX_STEP
  beq @change
  cmp #FX_STEP * 2
  beq @change
  cmp #FX_STEP * 3
  bne @next
  stz FX_T,x
@change:
  lda #1
  sta REDRAW
@next:
  dex
  bpl @fx
  rts

; DrawFx - every ring onto the canvas.
DrawFx:
  ldx #NUM_FX - 1
@fx:
  lda FX_T,x
  beq @next
  stx FX_I
  ldy #0
  cmp #FX_STEP
  bcc @size
  ldy #RING_POINTS
  cmp #FX_STEP * 2
  bcc @size
  ldy #RING_POINTS * 2
@size:
  sty FX_OFF
  lda FX_INK,x
  sta PINK
  lda #RING_POINTS
  sta FX_N
@point:
  ldx FX_I
  ldy FX_OFF
  lda FX_X,x
  clc
  adc RingX,y
  cmp #BOARD_X
  bcc @skip
  cmp #BOARD_RIGHT + 1
  bcs @skip
  sta PX
  lda FX_Y,x
  clc
  adc RingY,y
  cmp #BOARD_Y
  bcc @skip
  cmp #BOARD_BOTTOM + 1
  bcs @skip
  sta PY
  jsr CanvasPlot
  inc PX                           ; two pixels wide, to read as a ring
  jsr CanvasPlot
@skip:
  inc FX_OFF
  dec FX_N
  bne @point
  ldx FX_I
@next:
  dex
  bpl @fx
  rts

; =============================================================================
;   The CPU's specials
; =============================================================================

; AiSpecial - the move and shot are chosen: use the special as well?
AiSpecial:
  stz AI_SPEC
  lda SPECIAL_WAIT+ME
  bne @commit
  lda SHIP_C+ME
  sta HD_C1
  lda SHIP_R+ME
  sta HD_R1
  lda AI_KC
  sta HD_C2
  lda AI_KR
  sta HD_R2
  jsr HexDist
  sta AI_D
  lda OPP
  bne AiEasySpecial
  lda SHIP_FACTION+ME
  cmp #SP_MINE
  beq AiMine
  cmp #SP_CLOAK
  beq AiCloak
  cmp #SP_JUMP
  beq @jump
  stz AI_I                         ; flak: try hexes round the enemy
  stz AI_FS
  lda #AI_FLAK
  sta AI_PHASE
  rts
@jump:
  jmp AiJump
@commit:
  jmp AiCommit

; AiEasySpecial - now and then, without much thought.
AiEasySpecial:
  jsr Rnd
  and #7
  bne @commit
  lda SHIP_FACTION+ME
  cmp #SP_MINE
  beq AiMine
  cmp #SP_CLOAK
  beq @use
  cmp #SP_JUMP
  beq @jump
  lda AI_D                         ; flak, right at the enemy
  cmp #FLAK_RANGE + 1
  bcs @commit
  lda AI_KC
  sta AI_BAC
  lda AI_KR
  sta AI_BAR
  bra @use
@jump:
  lda AI_HIDDEN
  bne @commit
  lda AI_D
  cmp #JUMP_RANGE + 1
  bcs @commit
  lda AI_KC
  sta AI_BC
  lda AI_KR
  sta AI_BR
@use:
  inc AI_SPEC
@commit:
  jmp AiCommit

; AiMine - free with the shot: drop one whenever the enemy is anywhere near.
AiMine:
  lda AI_D
  cmp #8
  bcs @commit
  ldx #ME
  jsr OwnMineHere
  bcs @commit
  inc AI_SPEC
@commit:
  jmp AiCommit

; AiCloak - it costs the shot, so more often when behind.
AiCloak:
  lda AI_D
  cmp #7
  bcs @commit
  ldy #1
  lda SHIP_HP_HI+ME
  cmp SHIP_HP_HI+FOE
  bcs @roll
  ldy #2
@roll:
  sty AI_TMP
  jsr Rnd
  and #3
  cmp AI_TMP
  bcs @commit
  inc AI_SPEC
@commit:
  jmp AiCommit

; AiJump - dive on a ship it could finish or one that sits still, or get away
; when badly hurt.
AiJump:
  lda AI_HIDDEN
  bne @away
  lda AI_D
  cmp #JUMP_RANGE + 1
  bcs @away
  lda SHIP_HP_HI+ME
  cmp #RAM_RECOIL + 1
  bcc @away
  lda SHIP_HP_HI+FOE
  cmp #RAM_DAMAGE + 1
  bcc @dive
  lda AI_STAYED
  beq @away
  jsr Rnd
  and #1
  bne @away
@dive:
  lda AI_KC
  sta AI_BC
  lda AI_KR
  sta AI_BR
  inc AI_SPEC
  jmp AiCommit
@away:
  lda SHIP_HP_HI+ME
  cmp #AI_HURT
  bcs @commit
  lda AI_D
  cmp #5
  bcs @commit
  lda AI_D
  sta AI_S
  stz AI_I
@dir:
  lda #JUMP_RANGE
  sta AI_K
@hop:
  lda SHIP_C+ME
  sta AI_HC
  lda SHIP_R+ME
  sta AI_HR
  ldx AI_I
  lda DirQ,x
  jsr TimesK
  sta AI_HQ
  ldx AI_I
  lda DirR,x
  jsr TimesK
  sta AI_HS
  jsr HexStep
  bcc @shorter
  lda AI_OC
  sta HD_C1
  lda AI_OR
  sta HD_R1
  jsr HexDist                      ; HD_C2, HD_R2 still hold the enemy
  cmp AI_S
  bcc @shorter
  beq @shorter
  sta AI_S
  lda AI_OC
  sta AI_BC
  lda AI_OR
  sta AI_BR
  lda #1
  sta AI_SPEC
@shorter:
  dec AI_K
  dec AI_K
  bne @hop
  inc AI_I
  lda AI_I
  cmp #6
  bne @dir
@commit:
  jmp AiCommit

; TimesK - A (1, 0 or -1) times AI_K.
TimesK:
  cmp #0
  beq @done
  bmi @minus
  lda AI_K
  rts
@minus:
  lda #0
  sec
  sbc AI_K
@done:
  rts

; AiFlak - one slice: how much of where the enemy may end would a burst on this
; hex catch? The enemy's hex first, then the six round it.
AiFlak:
  lda AI_KC
  sta AI_OC
  sta AI_HC
  lda AI_KR
  sta AI_OR
  sta AI_HR
  ldx AI_I
  beq @have
  lda DirQ-1,x
  sta AI_HQ
  lda DirR-1,x
  sta AI_HS
  jsr HexStep
  bcc @next
@have:
  lda SHIP_C+ME
  sta HD_C1
  lda SHIP_R+ME
  sta HD_R1
  lda AI_OC
  sta HD_C2
  lda AI_OR
  sta HD_R2
  jsr HexDist
  cmp #FLAK_RANGE + 1
  bcs @next
  stz AI_S
  stz AI_K
@end:
  ldy AI_K
  lda AI_EC,y
  sta HD_C1
  lda AI_ER,y
  sta HD_R1
  jsr HexDist
  cmp #2
  bcs @far
  ldy AI_K
  lda AI_EW,y
  clc
  adc AI_S
  sta AI_S
@far:
  inc AI_K
  lda AI_K
  cmp AI_N
  bne @end
  lda AI_S
  cmp AI_FS
  bcc @next
  beq @next
  sta AI_FS
  lda AI_OC
  sta AI_FC
  lda AI_OR
  sta AI_FR
@next:
  inc AI_I
  lda AI_I
  cmp #7
  beq @decide
  rts
@decide:
  lda AI_FS
  beq @commit
  ldx #FLAK_DAMAGE
  jsr Mul8
  asl PROD
  rol PROD+1
  ldx AI_BW
  lda PROD
  cmp AI_BS_LO,x
  lda PROD+1
  sbc AI_BS_HI,x
  bcc @rare
  jsr Rnd                          ; worth at least half the shot: 1 in 2
  and #1
  bne @commit
  bra @use
@rare:
  jsr Rnd                          ; otherwise 1 in 4, to keep the enemy moving
  and #3
  bne @commit
@use:
  lda AI_FC
  sta AI_BAC
  lda AI_FR
  sta AI_BAR
  inc AI_SPEC
@commit:
  jmp AiCommit
