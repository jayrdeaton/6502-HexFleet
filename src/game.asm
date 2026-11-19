; =============================================================================
;   game.asm - the title screen, planning and the end of a battle
; =============================================================================
;   A battle goes: each person plans in turn, the machine passed between them
;   (a handoff screen hides one plan from the next person), then the turn
;   plays out for everyone (turn.asm), until one ship or none is left.
; =============================================================================

.segment "BANK00"

; --- Factions: Vanguard, Raider, Swarm, Wraith ---
FactionNames:
  .word TxtVanguard, TxtRaider, TxtSwarm, TxtWraith
MaxHull:
  .byte 125, 105, 125, 115
TorpedoDamage:
  .byte 30, 35, 35, 35
SeatRow:                           ; palette rows: azure, orange, green, violet
  .byte $9, $3, $6, $B
SeatInk:
  .byte INK_AZURE, INK_ORANGE, INK_GREEN, INK_VIOLET
AltRow:                            ; a second ship of the same faction
  .byte $8, $2, $5, $C
AltInk:
  .byte INK_CYAN, INK_RED, INK_LIME, INK_PINK

; Where each seat starts: top-left and bottom-right, facing each other
SpawnC:
  .byte 0, 9
SpawnR:
  .byte 0, 14
SpawnHead:
  .byte 6, 0

TxtVanguard:  .asciiz "VANGUARD"
TxtRaider:    .asciiz "RAIDER"
TxtSwarm:     .asciiz "SWARM"
TxtWraith:    .asciiz "WRAITH"
TxtTitle:     .asciiz "HEXFLEET"
TxtTurn:      .asciiz "TURN "
TxtPlayer:    .asciiz "PLAYER "
TxtUpDown:    .asciiz "UP/DN: SEAT"
TxtLeftRight: .asciiz "LT/RT: SHIP"
TxtStart:     .asciiz "FIRE: START"
TxtPressFire: .asciiz "PRESS FIRE"
TxtPickMove:  .asciiz "PICK A MOVE"
TxtUpTo3:     .asciiz "UP TO 3 HEX"
TxtTooFar:    .asciiz "TOO FAR"
TxtPickAim:   .asciiz "PICK TARGET"
TxtShipBack:  .asciiz "SHIP: REDO"
TxtLockIn:    .asciiz "LOCK IN?"
TxtFireYes:   .asciiz "FIRE: YES"
TxtWeapon:    .asciiz "WEAPON"
TxtLaser:     .asciiz "LASER"
TxtTorpedo:   .asciiz "TORPEDO"
TxtSwap:      .asciiz "B/X: SWAP"
TxtOrdersIn:  .asciiz "ORDERS IN"
TxtFirePlay:  .asciiz "FIRE: PLAY"
TxtWins:      .asciiz " WINS"
TxtDraw:      .asciiz "DRAW"
TxtGameOver:  .asciiz "GAME OVER"
TxtFireMenu:  .asciiz "FIRE: MENU"
TxtCpu:       .asciiz "CPU"
TxtOpponent:  .asciiz "OPPONENT"
TxtNormal:    .asciiz "NORMAL"
TxtEasy:      .asciiz "EASY"
TxtMusicOn:   .asciiz "MUSIC ON"
TxtMusicOff:  .asciiz "MUSIC OFF"
TxtHuman:     .asciiz "2 PLAYERS"
TxtYouWin:    .asciiz "YOU WIN"
TxtCpuWins:   .asciiz "CPU WINS"
OppNames:
  .word TxtNormal, TxtEasy, TxtHuman, TxtLink

; --- The main loop ---

MainLoop:
  jsr ReadInput
  jsr Dispatch
  jsr WaitFrame
  bra MainLoop

Dispatch:
  lda STATE
  asl a
  tax
  jmp (StateTable,x)

StateTable:
  .word TitleFrame, HandoffFrame, PlanFrame, ReadyFrame, OverFrame, NameFrame
  .word LinkFrame, LinkWaitFrame

; --- Small helpers ---

; SetColors - each ship's sprite row and ink from its faction; a second ship
; of the same faction takes the faction's other colors.
SetColors:
  jsr PickColors
  jmp CanvasColors

PickColors:
  ldx SHIP_FACTION
  lda SeatRow,x
  sta SHIP_ROW
  lda SeatInk,x
  sta SHIP_INK
  ldx SHIP_FACTION+1
  cpx SHIP_FACTION
  beq @same
  lda SeatRow,x
  sta SHIP_ROW+1
  lda SeatInk,x
  sta SHIP_INK+1
  rts
@same:
  lda AltRow,x
  sta SHIP_ROW+1
  lda AltInk,x
  sta SHIP_INK+1
  rts

; ShowShip - ship X's sprite centered on (HX, HY). A cloaked ship is gray for
; whoever may see it and hidden from anyone else. Keeps X.
ShowShip:
  lda CLOAKED,x
  beq @plain
  jsr CanView
  bcs @ghost
  jmp HideSprite
@ghost:
  lda #ROW_GRAY
  bra @row
@plain:
  lda SHIP_ROW,x
@row:
  ora #SPR_FRONT
  pha
  lda SHIP_FACTION,x               ; 12 drawings a faction, 4 patterns each
  asl a
  adc SHIP_FACTION,x
  asl a
  asl a
  clc
  adc SHIP_HEAD,x
  asl a
  asl a
  sta MTMP
  ply
  lda MTMP
  jmp PlaceSprite                  ; ship slots are the ships' indexes

; ShipCenter - HX, HY of ship X's hex. Keeps X.
ShipCenter:
  phx
  ldy SHIP_R,x
  lda SHIP_C,x
  tax
  jsr HexCenter
  plx
  rts

; ShowShipsOnHexes - every ship on its hex, or hidden if it's gone.
ShowShipsOnHexes:
  ldx #0
@loop:
  lda SHIP_ALIVE,x
  beq @hide
  jsr ShipCenter
  jsr ShowShip
  bra @next
@hide:
  jsr HideSprite
@next:
  inx
  cpx #NUM_SHIPS
  bne @loop
  rts

; ShowBoard - the ships, and what the viewer may see of mines and cloaks.
ShowBoard:
  jsr ShowShipsOnHexes
  jsr ShowMines
  jmp ShowSeen

; ClearMessages - blank the panel's message rows.
ClearMessages:
  lda #ROW_MSG1
@loop:
  pha
  jsr PanelClear
  pla
  inc a
  cmp #ROW_MSG7 + 1
  bne @loop
  rts

; PrintPlayer - panel row A: "PLAYER 1" for ship PLAYER, in its ink.
PrintPlayer:
  pha
  ldx PLAYER
  lda SHIP_INK,x
  sta TXT_INK
  jsr LineStart
  jsr SeatIsCpu
  bcc @person
  ldx #<TxtCpu
  ldy #>TxtCpu
  jsr LineStr
  bra @show
@person:
  ldx #<TxtPlayer
  ldy #>TxtPlayer
  jsr LineStr
  lda PLAYER
  clc
  adc #'1'
  jsr LineChar
@show:
  pla
  jmp LineShow

; SeatIsCpu - carry set if seat PLAYER is the CPU's.
SeatIsCpu:
  lda PLAYER
  beq VsPerson
  ; falls through

; VsCpu - carry set if the opponent is the CPU.
VsCpu:
  lda OPP
  cmp #2
  bcs VsPerson
  sec
  rts
VsPerson:
  clc
  rts

; AddShipName - the name of ship X's faction onto the line.
AddShipName:
  lda SHIP_FACTION,x
  asl a
  tax
  lda FactionNames+1,x
  tay
  lda FactionNames,x
  tax
  jmp LineStr

DrawTurnLine:
  lda #INK_WHITE
  sta TXT_INK
  jsr LineStart
  ldx #<TxtTurn
  ldy #>TxtTurn
  jsr LineStr
  lda TURN
  jsr LineNum
  lda #ROW_TURN
  jmp LineShow

; ShipRow - A = the panel row of ship X's name. Keeps X.
ShipRow:
  txa
  asl a
  stx MTMP
  clc
  adc MTMP
  adc #ROW_NAME0
  rts

; DrawNameLine - "P1 VANGUARD" in the ship's ink. Keeps X.
DrawNameLine:
  stx HPL_SHIP
  lda SHIP_INK,x
  sta TXT_INK
  jsr LineStart
  jsr IsLink
  bne @local
  lda HPL_SHIP                     ; "ME RAIDER" and "VS RAIDER"
  cmp MY_SEAT
  bne @them
  lda #'M'
  jsr LineChar
  lda #'E'
  bra @tag
@them:
  lda #'V'
  jsr LineChar
  lda #'S'
  bra @tag
@local:
  lda HPL_SHIP
  beq @person
  jsr VsCpu
  bcc @person
  lda #'A'                         ; "AI RAIDER"
  jsr LineChar
  lda #'I'
  bra @tag
@person:
  lda #'P'
  jsr LineChar
  lda HPL_SHIP
  clc
  adc #'1'
@tag:
  jsr LineChar
  lda #' '
  jsr LineChar
  ldx HPL_SHIP
  jsr AddShipName
  ldx HPL_SHIP
  jsr ShipRow
  jsr LineShow
  ldx HPL_SHIP
  rts

; DrawHpLine - ship X's hull: a 7-cell bar and the number. Keeps X.
DrawHpLine:
  stx HPL_SHIP
  lda SHIP_HP_HI,x
  sta HP_SHOWN,x
  lda SHIP_INK,x
  sta TXT_INK
  lda SHIP_HP_HI,x
  ldx #56
  jsr Mul8
  lda PROD
  sta DIVIDEND
  lda PROD+1
  sta DIVIDEND+1
  ldx HPL_SHIP
  ldy SHIP_FACTION,x
  lda MaxHull,y
  sta DIVISOR
  jsr Div16
  lda QUOT
  sta HPL_W
  jsr LineStart
  ldy #7
@cell:
  lda HPL_W
  cmp #8
  bcc @part
  lda #8
@part:
  pha
  clc
  adc #PAT_BAR
  jsr LineChar
  pla
  eor #$FF
  sec
  adc HPL_W
  sta HPL_W
  dey
  bne @cell
  lda #' '
  jsr LineChar
  ldx HPL_SHIP
  lda SHIP_HP_HI,x
  jsr NumToText
  lda DIGITS
  jsr LineChar
  lda DIGITS+1
  jsr LineChar
  lda DIGITS+2
  jsr LineChar
  ldx HPL_SHIP
  jsr ShipRow
  inc a
  jsr LineShow
  ldx HPL_SHIP
  rts

HideMarkers:
  ldx #SLOT_CURSOR
  jsr HideSprite
  ldx #SLOT_DEST
  jsr HideSprite
  ldx #SLOT_AIM
  jmp HideSprite

; =============================================================================
;   Title
; =============================================================================

EnterTitle:
  lda #ST_TITLE
  sta STATE
  stz SEL
  jsr SoundOff
  lda #TUNE_MENU
  jsr PlayMusic
  jsr LinkOff
  jsr ResetSpecials
  jsr ClearLayer1
  lda #INK_CYAN
  sta TXT_INK
  lda #3
  ldx #<TxtTitle
  ldy #>TxtTitle
  jsr BigText
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_HELP1
  ldx #<TxtUpDown
  ldy #>TxtUpDown
  jsr Print
  lda #ROW_HELP2
  ldx #<TxtLeftRight
  ldy #>TxtLeftRight
  jsr Print
  lda #INK_WHITE
  sta TXT_INK
  lda #ROW_HELP3
  ldx #<TxtStart
  ldy #>TxtStart
  jsr Print
  jsr DrawScores
  ; falls through

; DrawSeats - both seats' lines, and their ships where they'll start.
DrawSeats:
  jsr SetColors
  stz PLAYER
  jsr DrawSeat
  inc PLAYER
  jsr DrawSeat
  stz PLAYER
  jsr DrawOpponent
  jsr DrawMusicRow
  jsr DrawTip
  ldx #0
@ship:
  lda SpawnHead,x
  sta SHIP_HEAD,x
  lda SpawnC,x
  sta SHIP_C,x
  lda SpawnR,x
  sta SHIP_R,x
  lda #1
  sta SHIP_ALIVE,x
  inx
  cpx #NUM_SHIPS
  bne @ship
  jsr HideMarkers
  jsr ShowShipsOnHexes
  jmp UploadSprites

; DrawSeat - "PLAYER 1", then "<VANGUARD>" with arrows on the seat being set.
DrawSeat:
  ldx PLAYER
  jsr ShipRow
  sta RR
  jsr PrintPlayer
  jsr LineStart
  lda PLAYER
  cmp SEL
  bne @plain
  lda #'<'
  bra @first
@plain:
  lda #' '
@first:
  jsr LineChar
  lda PLAYER
  beq @name
  jsr IsLink                       ; the other seat is the other machine's
  bne @name
  ldx #<TxtLinked
  ldy #>TxtLinked
  jsr LineStart
  jsr LineStr
  bra @show
@name:
  ldx PLAYER
  jsr AddShipName
  lda PLAYER
  cmp SEL
  bne @show
  lda #'>'
  jsr LineChar
@show:
  lda RR
  inc a
  jmp LineShow

; DrawOpponent - who plays the second ship.
DrawOpponent:
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_OPP
  ldx #<TxtOpponent
  ldy #>TxtOpponent
  jsr Print
  lda #INK_WHITE
  sta TXT_INK
  jsr LineStart
  lda SEL
  cmp #2
  bne @plain
  lda #'<'
  bra @first
@plain:
  lda #' '
@first:
  jsr LineChar
  lda OPP
  asl a
  tax
  lda OppNames+1,x
  tay
  lda OppNames,x
  tax
  jsr LineStr
  lda SEL
  cmp #2
  bne @show
  lda #'>'
  jsr LineChar
@show:
  lda #ROW_OPP + 1
  jmp LineShow

; DrawMusicRow - the title's music setting.
DrawMusicRow:
  lda #INK_GRAY
  sta TXT_INK
  jsr LineStart
  lda SEL
  cmp #3
  bne @plain
  lda #INK_WHITE
  sta TXT_INK
  lda #'<'
  bra @first
@plain:
  lda #' '
@first:
  jsr LineChar
  ldx #<TxtMusicOn
  ldy #>TxtMusicOn
  lda MUS_ON
  bne @text
  ldx #<TxtMusicOff
  ldy #>TxtMusicOff
@text:
  jsr LineStr
  lda SEL
  cmp #3
  bne @show
  lda #'>'
  jsr LineChar
@show:
  lda #ROW_MUSIC
  jmp LineShow

TitleFrame:
  inc RND                          ; the moment you start seeds the CPU
  bne @seeded
  inc RND+1
@seeded:
  lda EV_DIR
  cmp #DIR_UP
  beq @up
  cmp #DIR_DOWN
  beq @down
  cmp #DIR_LEFT
  beq @prev
  cmp #DIR_RIGHT
  beq @next
  lda EV_FIRE
  bne @fire
  rts
@fire:
  jsr SndCommit
  jsr IsLink
  beq @link
  jmp StartBattle
@link:
  jmp EnterLink
@up:
  lda SEL
  bne @upOne
  lda #4
@upOne:
  dec a
  sta SEL
  cmp #1
  bne @redraw
  jsr IsLink                       ; the other machine sets the second seat
  bne @redraw
  stz SEL
  bra @redraw
@down:
  lda SEL
  inc a
  cmp #4
  bne @downOne
  lda #0
@downOne:
  sta SEL
  cmp #1
  bne @redraw
  jsr IsLink
  bne @redraw
  lda #2
  sta SEL
  bra @redraw
@prev:
  lda SEL
  cmp #3
  beq @music
  cmp #2
  beq @oppPrev
  ldx SEL
  lda SHIP_FACTION,x
  dec a
  and #3
  sta SHIP_FACTION,x
  bra @redraw
@music:
  jsr ToggleMusic
  bra @redraw
@oppPrev:
  lda OPP
  bne @oppBack
  lda #4
@oppBack:
  dec a
  sta OPP
  bra @redraw
@next:
  lda SEL
  cmp #3
  beq @music
  cmp #2
  beq @oppNext
  ldx SEL
  lda SHIP_FACTION,x
  inc a
  and #3
  sta SHIP_FACTION,x
  bra @redraw
@oppNext:
  lda OPP
  inc a
  cmp #4
  bne @oppSet
  lda #0
@oppSet:
  sta OPP
@redraw:
  jsr SndBack
  jmp DrawSeats
@done:
  rts

; =============================================================================
;   A battle
; =============================================================================

StartBattle:
  lda #1
  sta TURN
  lda #TUNE_BATTLE
  jsr PlayMusic
  jsr SetColors
  jsr ResetSpecials
  ldx #0
@ship:
  lda #1
  sta SHIP_ALIVE,x
  ldy SHIP_FACTION,x
  lda MaxHull,y
  sta SHIP_HP_HI,x
  stz SHIP_HP_LO,x
  lda SpawnC,x
  sta SHIP_C,x
  lda SpawnR,x
  sta SHIP_R,x
  lda SpawnHead,x
  sta SHIP_HEAD,x
  stz PLAN_WEAPON,x
  inx
  cpx #NUM_SHIPS
  bne @ship
  jsr ClearLayer1
  jsr DrawTurnLine
  ldx #0
@panel:
  jsr DrawNameLine
  jsr DrawHpLine
  inx
  cpx #NUM_SHIPS
  bne @panel
  jsr HideMarkers
  jsr ShowBoard
  jsr UploadSprites
  lda #$FF
  sta AI_LC                        ; the CPU hasn't seen the enemy yet
  ; falls through

; BeginTurn - against the CPU you plan straight away while it thinks.
BeginTurn:
  jsr IsLink
  bne @here
  jsr LinkNewTurn
  lda MY_SEAT
  sta PLAYER
  jmp EnterPlan
@here:
  stz PLAYER
  jsr VsCpu
  bcc EnterHandoff
  jsr AiStart
  jmp EnterPlan

; --- Handoff: the machine goes to the next person to plan ---

EnterHandoff:
  lda #ST_HANDOFF
  sta STATE
  lda #VIEW_NONE
  sta VIEWER
  jsr HideMarkers
  jsr ShowBoard
  jsr UploadSprites
  jsr ClearMessages
  lda #ROW_MSG2
  jsr PrintPlayer
  lda #INK_WHITE
  sta TXT_INK
  lda #ROW_MSG3
  ldx #<TxtPressFire
  ldy #>TxtPressFire
  jmp Print

HandoffFrame:
  lda EV_FIRE
  beq @wait
  jsr SndPick
  jmp EnterPlan
@wait:
  rts

; --- Planning ---
;
; B swaps through what the ship can do this turn: Laser, Torpedo, then its
; special if it's ready. A Raider's mine goes with the shot, so it adds Laser and
; Torpedo with a mine. A flak shell is aimed like a shot but only so far; a cloak
; needs no aim; a jump replaces the move and needs no aim.

EnterPlan:
  lda #ST_PLAN
  sta STATE
  lda #PH_MOVE
  sta PHASE
  stz HAS_AIM
  ldx PLAYER
  stx VIEWER
  stz PLAN_SPECIAL,x
  lda SHIP_C,x
  sta CUR_C
  lda SHIP_R,x
  sta CUR_R
  jsr ClearMessages
  jsr IsLink
  bne @seat
  ldx PLAYER
  lda SHIP_INK,x
  sta TXT_INK
  lda #ROW_MSG1
  ldx #<TxtOrders
  ldy #>TxtOrders
  jsr Print
  bra @named
@seat:
  lda #ROW_MSG1
  jsr PrintPlayer
@named:
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_MSG6
  ldx #<TxtSwap
  ldy #>TxtSwap
  jsr Print
  jsr DrawSpecial
  jsr ShowBoard
  ; falls through

; ShowPhase - the panel, the board's marks and the markers for this phase.
ShowPhase:
  jsr DrawPhaseHints
  jsr DrawWeapon
  jsr PhaseCanvas
  jmp UpdateMarkers

; PhaseCanvas - how far the ship can reach with what's being picked now.
PhaseCanvas:
  lda PHASE
  bne @notMove
  jsr IsJump
  beq @jump
  lda #MOVE_RANGE
  bra @draw
@jump:
  lda #JUMP_RANGE
@draw:
  sta RANGE
  jmp DrawRange
@notMove:
  cmp #PH_AIM
  bne @clear
  jsr IsFlak
  bne @clear
  lda #FLAK_RANGE
  bra @draw
@clear:
  jmp CanvasClear

; DrawRange - an outline round every hex within RANGE of the ship, along the
; board's own lines.
DrawRange:
  lda PLAYER
  inc a
  sta PINK
  jsr CanvasBegin
  jsr ShipToHex
  stz RR
@row:
  lda RR
  jsr RowLen
  sta T2
  stz RC
@hex:
  lda RC
  sta HD_C2
  lda RR
  sta HD_R2
  jsr HexDist
  cmp RANGE
  beq @edge                        ; at the limit of the reach
  bcs @next
  lda RR                           ; inside it: only the board's rim has an edge
  beq @edge
  cmp #ROWS - 1
  beq @edge
  lda RC
  beq @edge
  inc a
  cmp T2
  bne @next
@edge:
  jsr OutlineHex
@next:
  inc RC
  lda RC
  cmp T2
  bne @hex
  inc RR
  lda RR
  cmp #ROWS
  bne @row
  jmp CanvasFlush

; OutlineHex - hex (RC, RR): draw each side that has no reachable hex beyond it.
OutlineHex:
  ldx RC
  ldy RR
  jsr HexCenter
  stz MN_I
@side:
  ldx MN_I
  lda RR
  and #1
  bne @odd
  lda SideColEven,x
  bra @column
@odd:
  lda SideColOdd,x
@column:
  clc
  adc RC
  sta HD_C2
  lda RR
  clc
  adc SideRow,x
  sta HD_R2
  cmp #ROWS
  bcs @draw                        ; off the board
  jsr RowLen
  sta MN_COUNT
  lda HD_C2
  cmp MN_COUNT
  bcs @draw
  jsr HexDist
  cmp RANGE
  beq @nextSide
  bcc @nextSide
@draw:
  lda MN_I
  asl a
  sta MN_COUNT
  asl a
  asl a
  clc
  adc MN_COUNT
  adc MN_I                         ; 11 points a side
  sta MN_FREE
  lda #11
  sta MN_COUNT
@point:
  ldy MN_FREE
  lda HX
  clc
  adc SideX,y
  sta PX
  lda HY
  clc
  adc SideY,y
  sta PY
  jsr CanvasPlot
  inc MN_FREE
  dec MN_COUNT
  bne @point
@nextSide:
  inc MN_I
  lda MN_I
  cmp #6
  bne @side
  rts

; The six sides of a hex: right, left, upper right, upper left, lower right, lower
; left. The neighbor across each, then the pixels of the side from the hex's center,
; the same pixels as the grid's lines.
SideColEven:
  .byte 1, $FF, 1, 0, 1, 0
SideColOdd:
  .byte 1, $FF, 0, $FF, 0, $FF
SideRow:
  .byte 0, 0, $FF, $FF, 1, 1
SideX:
.repeat 11, I
  .byte 10
.endrepeat
.repeat 11, I
  .byte <(-10)
.endrepeat
.repeat 11, I
  .byte I
.endrepeat
.repeat 11, I
  .byte <(I - 10)
.endrepeat
.repeat 11, I
  .byte I
.endrepeat
.repeat 11, I
  .byte <(I - 10)
.endrepeat
SideY:
.repeat 11, I
  .byte <(I - 5)
.endrepeat
.repeat 11, I
  .byte <(I - 5)
.endrepeat
.repeat 11, I
  .byte <(I / 2 - 10)
.endrepeat
.repeat 11, I
  .byte <(5 - (I + 1) / 2 - 10)
.endrepeat
.repeat 11, I
  .byte <(10 - (I + 1) / 2)
.endrepeat
.repeat 11, I
  .byte <(5 + I / 2)
.endrepeat

; DrawPhaseHints - what the next pick does.
DrawPhaseHints:
  lda #INK_WHITE
  sta TXT_INK
  lda PHASE
  cmp #PH_AIM
  beq @aim
  cmp #PH_CONFIRM
  beq @confirm
  jsr IsJump
  beq @jump
  lda #ROW_MSG2
  ldx #<TxtPickMove
  ldy #>TxtPickMove
  jsr Print
  lda #ROW_MSG3
  ldx #<TxtUpTo3
  ldy #>TxtUpTo3
  bra @second
@jump:
  lda #ROW_MSG2
  ldx #<TxtJumpWhere
  ldy #>TxtJumpWhere
  jsr Print
  lda #ROW_MSG3
  ldx #<TxtUpTo6
  ldy #>TxtUpTo6
  bra @second
@aim:
  jsr NeedsAim
  bcc @confirm
  jsr IsFlak
  beq @flak
  lda #ROW_MSG2
  ldx #<TxtPickAim
  ldy #>TxtPickAim
  jsr Print
  lda #ROW_MSG3
  ldx #<TxtShipBack
  ldy #>TxtShipBack
  bra @second
@flak:
  lda #ROW_MSG2
  ldx #<TxtShellWhere
  ldy #>TxtShellWhere
  jsr Print
  lda #ROW_MSG3
  ldx #<TxtUpTo5
  ldy #>TxtUpTo5
  bra @second
@confirm:
  lda #ROW_MSG2
  ldx #<TxtLockIn
  ldy #>TxtLockIn
  jsr Print
  lda #ROW_MSG3
  ldx #<TxtFireYes
  ldy #>TxtFireYes
@second:
  pha
  lda #INK_GRAY
  sta TXT_INK
  pla
  jmp Print

; DrawWeapon - "WEAPON" and what's picked.
DrawWeapon:
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_MSG4
  ldx #<TxtWeapon
  ldy #>TxtWeapon
  jsr Print
  jmp DrawChoice

; UpdateMarkers - the cursor, and the move and aim picked so far.
UpdateMarkers:
  ldx CUR_C
  ldy CUR_R
  jsr HexCenter
  ldx #SLOT_CURSOR
  lda #PAT_CURSOR
  ldy #ROW_GRAY | SPR_FRONT
  jsr PlaceSprite
  ldx #SLOT_DEST
  jsr HideSprite
  ldx #SLOT_AIM
  jsr HideSprite
  lda PHASE
  beq @done                        ; nothing picked yet
  ldx PLAYER
  ldy PLAN_R,x
  lda PLAN_C,x
  tax
  jsr HexCenter
  ldx PLAYER
  lda SHIP_ROW,x
  ora #SPR_FRONT
  tay
  ldx #SLOT_DEST
  lda #PAT_DEST
  jsr PlaceSprite
  lda HAS_AIM
  beq @done
  jsr NeedsAim
  bcc @done
  ldx PLAYER
  ldy AIM_R,x
  lda AIM_C,x
  tax
  jsr HexCenter
  ldx PLAYER
  lda SHIP_ROW,x
  ora #SPR_FRONT
  tay
  ldx #SLOT_AIM
  lda #PAT_RETICLE
  jsr PlaceSprite
@done:
  jmp UploadSprites

; MoveCursor - one hex in direction A, staying on the board.
MoveCursor:
  cmp #DIR_UP
  beq @up
  cmp #DIR_DOWN
  beq @down
  cmp #DIR_LEFT
  beq @left
  lda CUR_R                        ; right
  jsr RowLen
  dec a
  cmp CUR_C
  beq @done
  inc CUR_C
  rts
@left:
  lda CUR_C
  beq @done
  dec CUR_C
  rts
@up:
  lda CUR_R
  beq @done
  dec CUR_R
  bra @clamp
@down:
  lda CUR_R
  cmp #ROWS - 1
  beq @done
  inc CUR_R
@clamp:
  lda CUR_R                        ; a 10-hex row has no column 10
  jsr RowLen
  cmp CUR_C
  bne @done
  dec CUR_C
@done:
  rts

; JumpPicked - A = 1 if ship PLAYER has a jump picked, otherwise 0.
JumpPicked:
  jsr IsJump
  beq @yes
  lda #0
  rts
@yes:
  lda #1
  rts

; SwapWeapon - on to the next thing the ship can do, and back to whichever pick
; that leaves to make.
SwapWeapon:
  jsr JumpPicked
  sta SW_OLD
  ldx PLAYER
  lda PLAN_SPECIAL,x
  bne @onSpecial
  lda PLAN_WEAPON,x
  bne @afterTorpedo
  inc PLAN_WEAPON,x                ; laser to torpedo
  bra @chosen
@afterTorpedo:
  stz PLAN_WEAPON,x                ; torpedo to the special, or back to laser
  lda SPECIAL_WAIT,x
  bne @chosen
  lda #1
  sta PLAN_SPECIAL,x
  bra @chosen
@onSpecial:
  lda SHIP_FACTION,x
  cmp #SP_MINE
  bne @off
  lda PLAN_WEAPON,x                ; laser and mine to torpedo and mine
  bne @off
  inc PLAN_WEAPON,x
  bra @chosen
@off:
  stz PLAN_SPECIAL,x
  stz PLAN_WEAPON,x
@chosen:
  jsr SndBack
  jsr JumpPicked
  cmp SW_OLD
  beq @sameMove
  stz HAS_AIM                      ; a jump on or off: pick where to go again
  lda #PH_MOVE
  bra @set
@sameMove:
  lda PHASE
  beq @show                        ; still picking the move
  jsr NeedsAim
  bcc @confirm
  lda HAS_AIM
  beq @aim
  jsr AimInReach
  bcs @confirm
  stz HAS_AIM
@aim:
  lda #PH_AIM
  bra @set
@confirm:
  lda #PH_CONFIRM
@set:
  sta PHASE
@show:
  jmp ShowPhase

; ShipToHex - HexDist's first hex is ship PLAYER's.
ShipToHex:
  ldx PLAYER
  lda SHIP_C,x
  sta HD_C1
  lda SHIP_R,x
  sta HD_R1
  rts

; CursorDist - A = hexes from ship PLAYER to the cursor.
CursorDist:
  jsr ShipToHex
  lda CUR_C
  sta HD_C2
  lda CUR_R
  sta HD_R2
  jmp HexDist

; AimInReach - carry set if the aim already picked suits what's picked now.
AimInReach:
  jsr IsFlak
  bne @fine
  jsr ShipToHex
  lda AIM_C,x
  sta HD_C2
  lda AIM_R,x
  sta HD_R2
  jsr HexDist
  cmp #FLAK_RANGE + 1
  bcs @far
@fine:
  sec
  rts
@far:
  clc
  rts

PlanFrame:
  jsr IsLink
  bne @local
  jsr LinkPoll
  lda LINK_BAD
  beq @input
  jmp LinkBroken
@local:
  jsr VsCpu
  bcc @input
  jsr AiWork
@input:
  lda EV_SWAP
  beq @noSwap
  jsr SwapWeapon
@noSwap:
  lda EV_DIR
  cmp #NO_DIR
  beq @noMove
  jsr MoveCursor
  lda PHASE
  cmp #PH_CONFIRM
  bne @moved
  stz HAS_AIM                      ; moving off the aim means aiming again
  lda #PH_AIM
  sta PHASE
  jsr ShowPhase
  bra @noMove
@moved:
  jsr UpdateMarkers
@noMove:
  lda EV_FIRE
  beq @done
  jmp PlanPick
@done:
  rts

; CursorOn - Z set if the cursor is on (A = column, X = row).
CursorOn:
  cmp CUR_C
  bne @done
  cpx CUR_R
@done:
  rts

PlanPick:
  lda PHASE
  cmp #PH_AIM
  beq @aim
  cmp #PH_CONFIRM
  bne @move
  jmp @confirm
@move:
  ; where to go: within a move, or a jump
  ldy #MOVE_RANGE
  jsr IsJump
  bne @reach
  ldy #JUMP_RANGE
@reach:
  sty RANGE
  jsr CursorDist
  cmp RANGE
  beq @inReach
  bcs @tooFar
@inReach:
  ldx PLAYER
  lda CUR_C
  sta PLAN_C,x
  lda CUR_R
  sta PLAN_R,x
  stz HAS_AIM
  jsr NeedsAim
  bcc @toConfirm
  lda #PH_AIM
  bra @phase
@tooFar:
  jsr SndError
  lda #INK_RED
  sta TXT_INK
  lda #ROW_MSG2
  ldx #<TxtTooFar
  ldy #>TxtTooFar
  jmp Print
@aim:
  ldx PLAYER
  lda PLAN_C,x                     ; on the destination: swap weapons
  pha
  lda PLAN_R,x
  tax
  pla
  jsr CursorOn
  beq @swap
  ldx PLAYER
  lda SHIP_C,x                     ; on the ship: pick the move again
  pha
  lda SHIP_R,x
  tax
  pla
  jsr CursorOn
  beq @redo
  jsr NeedsAim
  bcc @toConfirm
  jsr IsFlak
  bne @setAim
  jsr CursorDist
  cmp #FLAK_RANGE + 1
  bcs @tooFar
@setAim:
  ldx PLAYER
  lda CUR_C
  sta AIM_C,x
  lda CUR_R
  sta AIM_R,x
  lda #1
  sta HAS_AIM
@toConfirm:
  lda #PH_CONFIRM
@phase:
  sta PHASE
  jsr SndPick
  jmp ShowPhase
@swap:
  jmp SwapWeapon
@redo:
  jsr SndBack
  stz HAS_AIM
  lda #PH_MOVE
  sta PHASE
  jmp ShowPhase
@confirm:
  jsr SndCommit
  jsr IsLink
  bne @notLinked
  jmp EnterLinkWait
@notLinked:
  jsr VsCpu
  bcc @nextPerson
  jsr AiFinish
  jmp PlayTurn
@nextPerson:
  inc PLAYER
  lda PLAYER
  cmp #NUM_SHIPS
  bcs EnterReady
  jmp EnterHandoff

; --- Every plan is in: someone presses fire to watch the turn ---

EnterReady:
  lda #ST_READY
  sta STATE
  lda #VIEW_NONE
  sta VIEWER
  jsr HideMarkers
  jsr ShowBoard
  jsr UploadSprites
  jsr ClearMessages
  lda #INK_WHITE
  sta TXT_INK
  lda #ROW_MSG2
  ldx #<TxtOrdersIn
  ldy #>TxtOrdersIn
  jsr Print
  lda #ROW_MSG3
  ldx #<TxtFirePlay
  ldy #>TxtFirePlay
  jmp Print

ReadyFrame:
  lda EV_FIRE
  bne PlayTurn
  rts

; PlayTurn - every plan is in: play it, then the next turn or the end.
PlayTurn:
  lda #VIEW_NONE                   ; a lone player still sees their own things
  sta VIEWER
  jsr VsCpu
  bcc @people
  stz VIEWER
  bra @view
@people:
  jsr IsLink                       ; each machine shows its own side
  bne @view
  lda MY_SEAT
  sta VIEWER
@view:
  jsr HideMarkers
  jsr UploadSprites
  jsr ClearMessages
  jsr RunTurn
  stz ANY                          ; who's left?
  lda #$FF
  sta WINNER
  ldx #0
@count:
  lda SHIP_ALIVE,x
  beq @gone
  inc ANY
  stx WINNER
@gone:
  inx
  cpx #NUM_SHIPS
  bne @count
  lda ANY
  cmp #2
  bcs @more
  jmp EnterOver
@more:
  inc TURN
  jsr DrawTurnLine
  jmp BeginTurn

; --- The end ---

EnterOver:
  lda #ST_OVER
  sta STATE
  lda #VIEW_ALL                    ; nothing left to hide
  sta VIEWER
  jsr ShowBoard
  jsr UploadSprites
  jsr SoundOff
  lda WINNER
  cmp #$FF
  beq @draw
  sta PLAYER
  tax
  lda SHIP_INK,x
  sta TXT_INK
  jsr VsCpu
  bcc @people
  lda #3
  ldx PLAYER
  bne @cpuWon
  ldx #<TxtYouWin
  ldy #>TxtYouWin
  jsr BigText
  bra @messages
@cpuWon:
  ldx #<TxtCpuWins
  ldy #>TxtCpuWins
  lda #3
  jsr BigText
  bra @messages
@people:
  jsr IsLink
  bne @named
  lda WINNER
  cmp MY_SEAT
  bne @lost
  ldx #<TxtYouWin
  ldy #>TxtYouWin
  bra @linkText
@lost:
  ldx #<TxtYouLose
  ldy #>TxtYouLose
@linkText:
  lda #3
  jsr BigText
  bra @messages
@named:
  jsr LineStart
  ldx #<TxtPlayer
  ldy #>TxtPlayer
  jsr LineStr
  lda PLAYER
  clc
  adc #'1'
  jsr LineChar
  ldx #<TxtWins
  ldy #>TxtWins
  jsr LineStr
  lda #2
  ldx #<LINEBUF
  ldy #>LINEBUF
  jsr BigText
  bra @messages
@draw:
  lda #INK_WHITE
  sta TXT_INK
  lda #3
  ldx #<TxtDraw
  ldy #>TxtDraw
  jsr BigText
@messages:
  jsr CheckRecord
  bcc @plain
  jmp EnterName
@plain:
  jmp ShowOver

OverFrame:
  jsr LinkPoll                     ; the other machine may still need an answer
  lda EV_FIRE
  beq @wait
  jsr SndPick
  jmp EnterTitle
@wait:
  rts
