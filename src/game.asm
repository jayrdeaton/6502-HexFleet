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
; Ship colors, by faction, then each faction's second color: palette row and ink
ColorRow:
  .byte $9, $3, $6, $B,  $8, $2, $5, $4
ColorInk:
  .byte INK_AZURE, INK_ORANGE, INK_GREEN, INK_VIOLET
  .byte INK_CYAN, INK_RED, INK_LIME, INK_YELLOW
SeatInk = ColorInk

TxtVanguard:  .asciiz "VANGUARD"
TxtRaider:    .asciiz "RAIDER"
TxtSwarm:     .asciiz "SWARM"
TxtWraith:    .asciiz "WRAITH"
TxtTitle:     .asciiz "HEXFLEET"
TxtTurn:      .asciiz "TURN "
TxtPlayer:    .asciiz "PLAYER "
TxtUpDown:    .asciiz "UP/DN: ITEM"
TxtLeftRight: .asciiz "LT/RT: SET"
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
TxtMusicOn:   .asciiz "MUSIC ON"
TxtMusicOff:  .asciiz "MUSIC OFF"
TxtAllFight:  .asciiz "FREE 4 ALL"
TxtTeams:     .asciiz "TEAMS"
TxtAlphaWins: .asciiz "ALPHA WINS"
TxtOmegaWins: .asciiz "OMEGA WINS"
TxtYouWin:    .asciiz "YOU WIN"
TxtCpuWins:   .asciiz "CPU WINS"

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

; SetColors - each seat takes its faction's color, or its second color, or else the
; first one no other seat has.
SetColors:
  stz T0                           ; colors taken, as bits
  ldx #0
@seat:
  ldy SHIP_FACTION,x
  lda ColorBit,y
  bit T0
  beq @take
  lda ColorBit+4,y
  bit T0
  bne @search
  tya
  clc
  adc #4
  tay
  bra @take2
@search:
  ldy #0
@look:
  lda ColorBit,y
  bit T0
  beq @take2
  iny
  bra @look
@take:
@take2:
  lda ColorBit,y
  ora T0
  sta T0
  lda ColorRow,y
  sta SHIP_ROW,x
  lda ColorInk,y
  sta SHIP_INK,x
  inx
  cpx #NUM_SHIPS
  bne @seat
  jmp CanvasColors

ColorBit:
  .byte 1, 2, 4, 8, 16, 32, 64, 128

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

; ShowFriends - while someone plans, a hex round each ship on their side.
ShowFriends:
  ldx #0
@ship:
  phx
  lda STATE
  cmp #ST_PLAN
  bne @hide
  cpx PLAYER
  beq @hide
  lda SHIP_ALIVE,x
  beq @hide
  ldy PLAYER
  lda SHIP_SIDE,y
  cmp SHIP_SIDE,x
  bne @hide
  jsr ShipCenter
  ldy PLAYER
  lda SHIP_ROW,y
  ora #SPR_FRONT
  tay
  txa
  clc
  adc #SLOT_FRIEND
  tax
  lda #PAT_DEST
  jsr PlaceSprite
  bra @next
@hide:
  txa
  clc
  adc #SLOT_FRIEND
  tax
  jsr HideSprite
@next:
  plx
  inx
  cpx #NUM_SHIPS
  bne @ship
  rts

HideFriends:
  ldx #SLOT_FRIEND + NUM_SHIPS - 1
@slot:
  jsr HideSprite
  dex
  cpx #SLOT_FRIEND - 1
  bne @slot
  rts

; ShowBoard - the ships, and what the viewer may see of mines and cloaks.
ShowBoard:
  jsr ShowShipsOnHexes
  jsr ShowMines
  jsr ShowFriends
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
  ldx PLAYER
  lda SHIP_SEAT,x
  clc
  adc #'1'
  jsr LineChar
@show:
  pla
  jmp LineShow

; SeatIsCpu - carry set if seat PLAYER is a CPU's.
SeatIsCpu:
  jsr IsLink
  beq VsPerson
  ldx PLAYER
  lda SEAT_KIND,x
  beq VsPerson
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
  clc
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
  ldx HPL_SHIP
  lda MODE
  cmp #M_TEAMS
  bne @kind
  lda SHIP_SIDE,x                  ; the team's letter
  clc
  adc #PAT_ALPHA
  bra @first
@kind:
  lda SEAT_KIND,x
  beq @person
  lda #'C'
  bra @first
@person:
  lda #'P'
@first:
  jsr LineChar
  ldx HPL_SHIP
  lda SHIP_SEAT,x
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

; ====================================================================
;   Setup: the title screen
; ====================================================================
;   A list to walk with up and down, and left and right to change what's picked:
;   the kind of battle, then for each seat who flies it and which ship, then the
;   music. Fire starts.

IT_MODE       = 0
IT_MUSIC      = 9

ModeNames:
  .word TxtAllFight, TxtTeams, TxtLink
WhoNames:
  .byte "PLRCPUEZYOFFYOULNK"
ShortNames:
  .byte "VANGRAIDSWRMWRTH"
; Where ships start: 2, 3, then 4 of them (4 a layout). Teams use the last, by seat.
SpawnC:
  .byte 0, 9, 0, 0,   0, 10, 0, 0,   0, 9, 0, 9
SpawnR:
  .byte 0, 14, 0, 0,  0, 7, 14, 0,   0, 0, 14, 14

; InitSeats - you against three Normal CPUs, everyone for themselves.
InitSeats:
  ldx #NUM_SHIPS - 1
@seat:
  txa
  sta CFG_FAC,x
  lda #KIND_CPU
  sta CFG_KIND,x
  dex
  bpl @seat
  stz CFG_KIND
  stz MODE
  ; falls through

; SetMode - the seats that are on become the battle's ships, numbered from 0.
SetMode:
  lda MODE
  cmp #M_LINK
  bne @seats
  lda #2                           ; linked: yours and the other machine's
  sta N_SHIPS
  ldx #1
@link:
  lda CFG_FAC,x
  sta SHIP_FACTION,x
  txa
  sta SHIP_SIDE,x
  sta SHIP_SEAT,x
  sta SEAT_SHIP,x
  stz SEAT_KIND,x
  dex
  bpl @link
  lda #$FF
  sta SEAT_SHIP+2
  sta SEAT_SHIP+3
  rts
@seats:
  ldx #0
  ldy #0
@seat:
  lda CFG_KIND,x
  cmp #KIND_OFF
  bne @on
  lda #$FF
  sta SEAT_SHIP,x
  bra @next
@on:
  sta SEAT_KIND,y
  lda CFG_FAC,x
  sta SHIP_FACTION,y
  txa
  sta SHIP_SEAT,y
  tya
  sta SEAT_SHIP,x
  lda MODE
  cmp #M_TEAMS
  bne @own
  txa                              ; seats 1 and 2 against 3 and 4
  lsr a
  bra @side
@own:
  tya
@side:
  sta SHIP_SIDE,y
  iny
@next:
  inx
  cpx #NUM_SHIPS
  bne @seat
  sty N_SHIPS
  rts

; ItemOk - carry set if list item A can be picked now.
ItemOk:
  cmp #IT_MODE
  beq @yes
  cmp #IT_MUSIC
  beq @yes
  sta T0
  ldx MODE
  cpx #M_LINK
  bne @notLink
  cmp #2                           ; linked, you only pick your own ship
  beq @yes
  bra @no
@notLink:
  and #1
  bne @yes                         ; who flies a seat can always change
  lda T0
  lsr a
  dec a
  tax
  lda CFG_KIND,x                   ; a seat that's off has no ship to pick
  cmp #KIND_OFF
  bne @yes
@no:
  clc
  rts
@yes:
  sec
  rts

; SelStep - on to the next item that can be picked, in direction A (1 or -1).
SelStep:
  sta T1
@step:
  lda SEL
  clc
  adc T1
  bpl @low
  lda #IT_MUSIC
@low:
  cmp #IT_MUSIC + 1
  bcc @set
  lda #IT_MODE
@set:
  sta SEL
  jsr ItemOk
  bcc @step
  rts

; ChangeItem - the picked item goes one way, A = 1 or -1.
ChangeItem:
  sta T1
  lda SEL
  bne @notMode
  lda MODE
  clc
  adc T1
  bpl @modeLow
  lda #M_LINK
@modeLow:
  cmp #M_LINK + 1
  bcc @mode
  lda #0
@mode:
  sta MODE
  cmp #M_TEAMS
  bne @modeSet
  ldx #NUM_SHIPS - 1               ; teams want full sides: empty seats become CPUs
@fill:
  lda CFG_KIND,x
  cmp #KIND_OFF
  bne @filled
  lda #KIND_CPU
  sta CFG_KIND,x
@filled:
  dex
  bpl @fill
@modeSet:
  rts
@notMode:
  cmp #IT_MUSIC
  bne @seat
  jmp ToggleMusic
@seat:
  dec a
  lsr a
  tax                              ; the seat
  bcc @who                         ; items 1, 3.. are who flies it
  lda CFG_FAC,x
  clc
  adc T1
  and #3
  sta CFG_FAC,x
  rts
@who:
  lda CFG_KIND,x
  clc
  adc T1
  and #3
  sta CFG_KIND,x
  rts

EnterTitle:
  lda #ST_TITLE
  sta STATE
  stz SEL
  jsr SoundOff
  lda #TUNE_MENU
  jsr PlayMusic
  jsr LinkOff
  jsr SetMode
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

; DrawSeats - the whole setup list, and the ships where they'll start.
DrawSeats:
  jsr SetMode
  jsr SetColors
  jsr DrawMode
  stz MN_I
@row:
  jsr DrawSeatRow
  inc MN_I
  lda MN_I
  cmp #NUM_SHIPS
  bne @row
  jsr DrawMusicRow
  jsr DrawTip
  jsr PlaceShips
  jsr HideMarkers
  jsr ShowShipsOnHexes
  jmp UploadSprites

; PlaceShips - every seat in play on its starting hex, facing the middle.
PlaceShips:
  ldx #0
@seat:
  stz SHIP_ALIVE,x
  cpx N_SHIPS
  bcs @next
  lda #1
  sta SHIP_ALIVE,x
  stx T0
  ldy MODE
  cpy #M_TEAMS
  bne @count
  lda SHIP_SEAT,x                  ; teams start along their own edges
  clc
  adc #8
  bra @spot
@count:
  lda N_SHIPS
  sec
  sbc #2
  bcs @layout
  lda #0
@layout:
  asl a
  asl a
  clc
  adc T0
@spot:
  tay
  lda SpawnC,y
  sta SHIP_C,x
  lda SpawnR,y
  sta SHIP_R,x
  jsr ShipCenter
  lda #114                         ; the board's middle hex
  sec
  sbc HX
  sta HDX
  lda #0
  sbc #0
  sta HDX+1
  lda #120
  sec
  sbc HY
  sta HDY
  lda #0
  sbc #0
  sta HDY+1
  phx
  jsr HeadingOf
  plx
  cmp #$FF
  beq @next
  sta SHIP_HEAD,x
@next:
  inx
  cpx #NUM_SHIPS
  bne @seat
  rts

; Marked - a list item's marker: '>' if item A is picked, otherwise a space.
Marked:
  cmp SEL
  bne @plain
  lda #'>'
  rts
@plain:
  lda #' '
  rts

; DrawMode - the kind of battle.
DrawMode:
  lda #INK_WHITE
  sta TXT_INK
  jsr LineStart
  lda #IT_MODE
  jsr Marked
  jsr LineChar
  lda MODE
  asl a
  tay
  lda ModeNames+1,y
  pha
  lda ModeNames,y
  tax
  ply
  jsr LineStr
  lda #ROW_MODE
  jmp LineShow

; DrawSeatRow - seat MN_I: its number or team, who flies it, its ship.
DrawSeatRow:
  ldx MN_I
  lda #INK_GRAY
  ldy SEAT_SHIP,x
  bmi @ink
  lda SHIP_INK,y
@ink:
  sta TXT_INK
  jsr LineStart
  ldx MN_I
  lda MODE
  cmp #M_TEAMS
  bne @number
  txa
  lsr a
  clc
  adc #PAT_ALPHA
  bra @first
@number:
  txa
  clc
  adc #'1'
@first:
  jsr LineChar
  lda MN_I
  asl a
  inc a
  jsr Marked
  jsr LineChar
  ldx MN_I
  lda MODE
  cmp #M_LINK
  bne @who
  ldy #12                          ; YOU
  cpx #0
  beq @name
  ldy #15                          ; LNK
  cpx #1
  beq @name
  ldy #9                           ; OFF
  bra @name
@who:
  lda CFG_KIND,x
  sta T0
  asl a
  adc T0
  tay
@name:
  ldx #3
@letter:
  lda WhoNames,y
  phx
  jsr LineChar
  plx
  iny
  dex
  bne @letter
  lda MN_I
  asl a
  clc
  adc #2
  jsr Marked
  jsr LineChar
  ldx MN_I
  lda SEAT_SHIP,x
  bmi @show                        ; no ship in a seat that's off
  lda MODE
  cmp #M_LINK
  bne @ship
  cpx #1
  beq @show                        ; the other machine picks that one
@ship:
  lda CFG_FAC,x
  asl a
  asl a
  tay
  ldx #4
@short:
  lda ShortNames,y
  phx
  jsr LineChar
  plx
  iny
  dex
  bne @short
@show:
  lda MN_I
  clc
  adc #ROW_SEATS
  jmp LineShow

; DrawMusicRow - the music setting.
DrawMusicRow:
  lda #INK_GRAY
  sta TXT_INK
  jsr LineStart
  lda #IT_MUSIC
  jsr Marked
  jsr LineChar
  ldx #<TxtMusicOn
  ldy #>TxtMusicOn
  lda MUS_ON
  bne @text
  ldx #<TxtMusicOff
  ldy #>TxtMusicOff
@text:
  jsr LineStr
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
  beq @left
  cmp #DIR_RIGHT
  beq @right
  lda EV_FIRE
  bne @fire
  rts
@fire:
  jsr IsLink
  beq @link
  jsr SidesLeft                    ; a battle needs two sides
  cmp #2
  bcs @go
  jmp SndError
@go:
  jsr SndCommit
  jmp StartBattle
@link:
  jsr SndCommit
  jmp EnterLink
@up:
  lda #$FF
  jsr SelStep
  bra @redraw
@down:
  lda #1
  jsr SelStep
  bra @redraw
@left:
  lda #$FF
  jsr ChangeItem
  bra @redraw
@right:
  lda #1
  jsr ChangeItem
@redraw:
  jsr SndBack
  jmp DrawSeats

; ====================================================================
;   A battle
; ====================================================================

StartBattle:
  lda #1
  sta TURN
  lda #TUNE_BATTLE
  jsr PlayMusic
  jsr SetMode
  jsr SetColors
  jsr ResetSpecials
  jsr PlaceShips
  stz HUMANS
  ldx #NUM_SHIPS - 1
@ship:
  stz PLAN_WEAPON,x
  stz SHIP_HP_LO,x
  stz SHIP_HP_HI,x
  lda #$FF
  sta PREV_C,x
  stz STAYED,x
  lda SHIP_ALIVE,x
  beq @next
  ldy SHIP_FACTION,x
  lda MaxHull,y
  sta SHIP_HP_HI,x
  lda SEAT_KIND,x
  bne @next
  inc HUMANS
  stx HUMAN_SEAT
@next:
  dex
  bpl @ship
  lda #AI_IDLE
  sta AI_PHASE
  jsr ClearLayer1
  jsr DrawTurnLine
  ldx #0
@panel:
  jsr DrawNameLine
  jsr DrawHpLine
  inx
  cpx N_SHIPS
  bne @panel
  jsr HideMarkers
  jsr ShowBoard
  jsr UploadSprites
  ; falls through

; BeginTurn - the CPUs start thinking, and the first person plans. Against only
; CPUs there's no handoff, and with no people the turn just plays.
BeginTurn:
  jsr IsLink
  bne @here
  jsr LinkNewTurn
  lda MY_SEAT
  sta PLAYER
  jmp EnterPlan
@here:
  jsr NoteStayed
  jsr AiBegin
  stz PLAYER
  jsr NextHuman
  bcs @person
  jmp CpusThenPlay
@person:
  jsr LiveHumans
  cmp #2
  bcs EnterHandoff
  jmp EnterPlan

; NoteStayed - which ships ended last turn where they began it.
NoteStayed:
  ldx #NUM_SHIPS - 1
@ship:
  stz STAYED,x
  lda SHIP_C,x
  cmp PREV_C,x
  bne @moved
  lda SHIP_R,x
  cmp PREV_R,x
  bne @moved
  inc STAYED,x
@moved:
  lda SHIP_C,x
  sta PREV_C,x
  lda SHIP_R,x
  sta PREV_R,x
  dex
  bpl @ship
  rts

; NextHuman - PLAYER moves to the next person still flying, from itself on.
; Carry clear if there's nobody left to plan.
NextHuman:
  ldx PLAYER
@seat:
  cpx N_SHIPS
  bcs @none
  lda SHIP_ALIVE,x
  beq @next
  lda SEAT_KIND,x
  beq @found
@next:
  inx
  bra @seat
@found:
  stx PLAYER
  sec
  rts
@none:
  clc
  rts

; LiveHumans - A = people still flying.
LiveHumans:
  stz T0
  ldx N_SHIPS
@seat:
  dex
  bmi @done
  lda SHIP_ALIVE,x
  beq @seat
  lda SEAT_KIND,x
  bne @seat
  inc T0
  bra @seat
@done:
  lda T0
  rts

; CpusThenPlay - everyone human has planned: finish the CPUs' thinking and go.
CpusThenPlay:
  jsr AiFinish
  jmp PlayTurn

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
  jsr AiWork
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
  jsr CanvasBegin
  ldx PLAYER
  jsr SetPen
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
  bne @here
  jmp EnterLinkWait
@here:
  inc PLAYER
  jsr NextHuman
  bcc @allIn
  jmp EnterHandoff
@allIn:
  jsr LiveHumans
  cmp #2
  bcc @alone
  jmp EnterReady
@alone:
  jmp CpusThenPlay

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
  jsr AiWork
  lda EV_FIRE
  beq @wait
  jmp CpusThenPlay
@wait:
  rts

; ReplayViewer - whose hidden things show while a turn plays: the people's side,
; if they're all on one.
ReplayViewer:
  jsr IsLink
  bne @local
  lda MY_SEAT
  sta VIEWER
  rts
@local:
  lda #VIEW_NONE
  sta VIEWER
  ldx #0
@seat:
  cpx N_SHIPS
  bcs @done
  lda SEAT_KIND,x
  bne @next
  lda VIEWER
  cmp #VIEW_NONE
  bne @other
  stx VIEWER
  bra @next
@other:
  tay
  lda SHIP_SIDE,y
  cmp SHIP_SIDE,x
  beq @next
  lda #VIEW_NONE                   ; people on different sides see nothing hidden
  sta VIEWER
  rts
@next:
  inx
  bra @seat
@done:
  rts

; PlayTurn - every plan is in: play it, then the next turn or the end.
PlayTurn:
  jsr ReplayViewer
  jsr HideMarkers
  jsr HideFriends
  jsr UploadSprites
  jsr ClearMessages
  jsr RunTurn
  jsr SidesLeft
  cmp #2
  bcs @more
  jmp EnterOver
@more:
  inc TURN
  jsr DrawTurnLine
  jmp BeginTurn

; SidesLeft - A = sides with a ship still flying; WINNER is one of those ships, or
; $FF if there are none.
SidesLeft:
  stz ANY
  stz T0                           ; which sides, as bits
  lda #$FF
  sta WINNER
  ldx N_SHIPS
@seat:
  dex
  bmi @done
  lda SHIP_ALIVE,x
  beq @seat
  stx WINNER
  ldy SHIP_SIDE,x
  lda SideBit,y
  bit T0
  bne @seat
  ora T0
  sta T0
  inc ANY
  bra @seat
@done:
  lda ANY
  rts

SideBit:
  .byte 1, 2, 4, 8

; --- The end ---

; WinText - the line to show for who won: X (low), Y (high), A its size.
WinText:
  ldy WINNER
  lda SHIP_SIDE,y
  sta T1
  jsr IsLink
  bne @local
  lda T1
  cmp MY_SEAT
  beq @you
  bra @lose
@local:
  lda HUMANS
  beq @cpus
  ; are the people all on one side?
  stz T2
  ldx N_SHIPS
@seat:
  dex
  bmi @oneSide
  lda SEAT_KIND,x
  bne @seat
  lda SHIP_SIDE,x
  ora #$80
  sta T0
  lda T2
  beq @first
  cmp T0
  bne @split
  bra @seat
@first:
  lda T0
  sta T2
  bra @seat
@split:
  lda MODE
  cmp #M_TEAMS
  beq @team
  ldy WINNER                       ; several players apart: name the winner
  lda SEAT_KIND,y
  bne @cpuWon
  jmp @named
@oneSide:
  lda T2
  and #$7F
  cmp T1
  beq @you
@cpuWon:
  ldx #<TxtCpuWins
  ldy #>TxtCpuWins
  lda #3
  rts
@you:
  ldx #<TxtYouWin
  ldy #>TxtYouWin
  lda #3
  rts
@lose:
  ldx #<TxtYouLose
  ldy #>TxtYouLose
  lda #3
  rts
@cpus:
  lda MODE
  cmp #M_TEAMS
  bne @cpuWon
@team:
  ldx #<TxtAlphaWins
  ldy #>TxtAlphaWins
  lda T1
  beq @teamText
  ldx #<TxtOmegaWins
  ldy #>TxtOmegaWins
@teamText:
  lda #2
  rts
@named:
  jsr LineStart
  ldx #<TxtPlayer
  ldy #>TxtPlayer
  jsr LineStr
  ldx WINNER
  lda SHIP_SEAT,x
  clc
  adc #'1'
  jsr LineChar
  ldx #<TxtWins
  ldy #>TxtWins
  jsr LineStr
  ldx #<LINEBUF
  ldy #>LINEBUF
  lda #2
  rts

EnterOver:
  lda #ST_OVER
  sta STATE
  lda #VIEW_ALL                    ; nothing left to hide
  sta VIEWER
  jsr ShowBoard
  jsr HideFriends
  jsr UploadSprites
  jsr SoundOff
  lda WINNER
  cmp #$FF
  beq @draw
  tax
  lda SHIP_INK,x
  sta TXT_INK
  jsr WinText
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
