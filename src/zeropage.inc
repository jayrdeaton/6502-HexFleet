; =============================================================================
;   zeropage.inc - constants, zero page and RAM layout for HexFleet
; =============================================================================

; --- Game ---
NUM_SHIPS     = 4          ; the most ships in a battle; N_SHIPS is how many are
MOVE_RANGE    = 3          ; hexes a ship may move in a turn
TICKS         = 64         ; a turn is 64 ticks; ships glide across all of them
CHARGE_TICKS  = 16         ; a laser charges for the first quarter, then burns
EXTRA_TICKS   = 48         ; at most this many more for torpedoes and wrecks
FRAMES_A_TICK = 2
TORP_SPEED    = 240        ; x 4 = 960: 3.75 pixels a tick (3 hexes a step)
HEX_PIXELS    = 20         ; center to center along a row
SHIP_REACH    = 8          ; how near a beam's line must pass to touch a ship
TORP_REACH_SQ = 100        ; a torpedo touches inside 10 pixels (squared)
BEAM_STOP_SQ  = 64         ; a beam is drawn up to 8 pixels from its target
HALF_TURN     = 31         ; the tick jumps land and new mines arm
LAST_TICK     = TICKS - 1  ; the tick flak shells burst

; --- Specials, numbered like the factions that have them ---
SP_FLAK       = 0
SP_MINE       = 1
SP_CLOAK      = 2
SP_JUMP       = 3
FLAK_RANGE    = 5
JUMP_RANGE    = 6
FLAK_DAMAGE   = 45
MINE_DAMAGE   = 25
SHOCK_DAMAGE  = 20
RAM_DAMAGE    = 40
RAM_RECOIL    = 20
AREA_REACH    = 25         ; a blast catches a ship centered this near
AREA_REACH_SQ = 625
MINE_LIMIT    = 3          ; each
NUM_MINES     = 12
NUM_FX        = 4          ; blast rings at once
FX_STEP       = 5          ; ticks at each of a ring's three sizes
RING_POINTS   = 32
TORP_SHELL    = 2          ; TORP_ON: a flak shell, not a torpedo
VIEW_NONE     = $FF        ; VIEWER: nobody's hidden things show
VIEW_ALL      = $FE        ; the battle's over: everyone's do
AI_HURT       = 31         ; under this hull a CPU Wraith jumps away

; --- Screen: Full mode, 40 x 30 cells of 8 x 8 ---
BOARD_X       = 4          ; the board's top-left pixel
BOARD_Y       = 5
BOARD_RIGHT   = BOARD_X + 220
BOARD_BOTTOM  = BOARD_Y + 230
ROWS          = 15         ; rows 0..14; even rows hold 10 hexes, odd rows 11
BOARD_CELLS   = 29         ; layer 1 columns over the board

PANEL_COL     = 29         ; the panel's first column
PANEL_W       = 11         ; its width in characters

ROW_TURN      = 1
ROW_NAME0     = 3          ; a ship's name, then its hull bar on the next row
ROW_MSG1      = 11
ROW_MSG2      = 13
ROW_MSG3      = 14
ROW_MSG4      = 16
ROW_MSG5      = 17
ROW_MSG6      = 19
ROW_MSG7      = 21
ROW_MUSIC     = 13         ; title: the music setting
ROW_READY     = 12         ; a linked game: the other side has locked in
ROW_MODE      = 1          ; title: the kind of battle
ROW_SEATS     = 3          ; title: a row for each seat, 3..6
ROW_TIP0      = 8          ; title: the picked seat's ship
ROW_TIP1      = 9         ; title: the selected seat's special
ROW_TIP2      = 10
ROW_TIP3      = 11
ROW_SCORES    = 15         ; the high scores: a heading and 5 rows
ROW_HELP1     = 22
ROW_HELP2     = 23
ROW_HELP3     = 25
BAND_ROW      = 12         ; the band behind big text
BAND_ROWS     = 5

; --- Video memory (all below $4000 except what's loaded once) ---
V_L0NAME      = $0000
V_L1NAME      = $0800
V_L1ATTR      = $1000
V_SPRATTR     = $1600
V_L1PAT       = $2000
V_L0PAT       = $3800
V_FONT        = $1800      ; the card's font, 1 bit a pixel, read to build the text
V_POOL        = V_L1PAT + 128 * 16  ; layer 1 patterns the canvas draws in
POOL_TILES    = 255        ; how many: patterns 128..382

; Layer 1's colors. Each is a 4-color sub-palette, number ink + 3: its value 1 is
; the ink and value 3 the dark behind big text. Sub-palettes 4 and 14 are the canvas:
; values 1 and 2 are ships 1 and 2, and value 3 is ship 3 in one and ship 4 in the
; other, so every pixel keeps its own color.
CANVAS_SUB    = 4
PAT_SOLID     = 10         ; a cell filled with value 3
PAT_ALPHA     = 11         ; the team letters: alpha, then omega
CANVAS_B      = 14         ; a second canvas sub-palette, for ship 4
BAND_SUB      = 5          ; any text sub-palette: its value 3 is the dark
M_ALL         = 0          ; MODE: everyone for themselves
M_TEAMS       = 1
M_LINK        = 2
KIND_PERSON   = 0          ; who flies a seat
KIND_CPU      = 1
KIND_EASY     = 2
KIND_OFF      = 3
INK_DARK      = 1
INK_WHITE     = 2
INK_GRAY      = 3
INK_AZURE     = 4
INK_ORANGE    = 5
INK_GREEN     = 6
INK_VIOLET    = 7
INK_CYAN      = 8
INK_RED       = 9
INK_LIME      = 10
INK_YELLOW    = 12

; Layer 1 patterns: 1..9 are hull bar cells, 0..8 pixels full; 32..127 the font
PAT_BAR       = 1

; --- Game states ---
ST_TITLE      = 0
ST_HANDOFF    = 1
ST_PLAN       = 2
ST_READY      = 3
ST_OVER       = 4
ST_NAME       = 5
ST_LINK       = 6          ; looking for the other machine
ST_WAIT       = 7          ; orders in, waiting for the other machine
OPP_LINK      = 3          ; OPP: a person on another machine

PH_MOVE       = 0
PH_AIM        = 1
PH_CONFIRM    = 2

W_LASER       = 0
W_TORPEDO     = 1

DIR_UP        = 0          ; also what 6502-Lib's input module expects
DIR_DOWN      = 1
DIR_LEFT      = 2
DIR_RIGHT     = 3
NO_DIR        = $FF

; --- Sprites ---
SPR_FRONT     = $40        ; attribute: in front of layer 1
ROW_GRAY      = 1          ; palette rows (sub-palettes)
ROW_ORANGE    = 3
PAT_CURSOR    = 48 * 4     ; pattern numbers count 8x8 blocks, 4 a sprite;
                           ; the 48 ship drawings come first
PAT_RETICLE   = 49 * 4
PAT_TORPEDO   = 50 * 4
PAT_EXPL1     = 51 * 4
PAT_EXPL2     = 52 * 4
PAT_EXPL3     = 53 * 4
PAT_DEST      = 54 * 4
PAT_SHELL     = 55 * 4
PAT_MINE      = 56 * 4
PAT_SEEN      = 57 * 4

SLOT_SHIP     = 0          ; 0..3
SLOT_TORP     = 4          ; 4..7
SLOT_EXPL     = 8          ; 8..11
SLOT_CURSOR   = 12
SLOT_DEST     = 13
SLOT_AIM      = 14
SLOT_MINE     = 15         ; 15..26
SLOT_SEEN     = 27         ; 27..30
SLOT_FX       = 31         ; 31..34
SLOT_FRIEND   = 35         ; 35..38
NUM_SLOTS     = 39
HIDE_Y        = 240        ; a sprite's Y below the picture

; --- Zero page: $3A is the bank shadow, the rest from $40 is ours ---
BANKSHDW      := $3A
BANK          = $E000      ; the Flash Cart's bank register

T0            := $40
T1            := $41
T2            := $42
SV_PTR        := $43       ; 2 bytes: the save record being read or written
SV_ERASE      := $45       ; erase the save sector first
SV_SLOT       := $46       ; the next free save record
NAME_POS      := $47       ; the initial being set
PTR0          := $48       ; 2 bytes
PTR1          := $4A       ; 2 bytes
CMAP          := $4C       ; 2 bytes: a cell's place in CELLMAP

PX            := $4E       ; canvas pixel
PY            := $4F
PMASK         := $50
PINK          := $51       ; its value, 1..3
ALLOC         := $52       ; where to look for a free canvas tile

MA            := $53       ; multiply: signed byte
MB            := $54       ; multiply: signed 16-bit (|value| < 256)
PROD          := $56       ; 2 bytes
DIVIDEND      := $58       ; 2 bytes
DIVISOR       := $5A
QUOT          := $5B       ; 2 bytes
REM           := $5D
SQRT_IN       := $5E       ; 2 bytes

JOY_STATE     := $60       ; joystick 1, active low (6502-Lib)
JOY_STATE2    := $61       ; joystick 2
KB_DIR        := $62       ; required by 6502-Lib's keyboard routines,
KB_FIRE       := $63       ; which HexFleet doesn't call
KB_DIR_P1     := $64
KB_DIR_P2     := $65
KB_FIRE_P1    := $66
KB_FIRE_P2    := $67

HELD_DIR      := $68       ; joystick direction held, or NO_DIR
REPEAT_T      := $69       ; frames until a held direction repeats
EV_DIR        := $6A       ; this frame's direction press, or NO_DIR
EV_FIRE       := $6B       ; 1 if fire was pressed this frame
EV_SWAP       := $6C       ; 1 if swap was pressed this frame
PREV_BTN      := $6D       ; last frame's joystick buttons (active high)

STATE         := $6E
PLAYER        := $6F       ; the ship being planned
PHASE         := $70
CUR_C         := $71       ; the planning cursor
CUR_R         := $72
TURN          := $73
TICK          := $74
SEL           := $75       ; title screen: the seat being set up
VIEWER        := $76       ; whose hidden things show: a ship, or VIEW_*
WINNER        := $77       ; ship index, or $FF for a draw

TXT_INK       := $78
TXT_PTR       := $79       ; 2 bytes
LINE_N        := $7B       ; characters in LINEBUF
BIG_X         := $7C       ; big text: left pixel
BIG_Y         := $7D       ; top pixel
BIG_S         := $7E       ; scale
HX            := $7F       ; hex center (out of HexCenter)
HY            := $80

LX            := $81       ; line drawing
LY            := $82
LAX           := $83       ; |dx|
LAY           := $84       ; |dy|
LSX           := $85       ; x step: 1 or $FF
LSY           := $86
LERR          := $87
LTX           := $88       ; the ship the beam stops on (center)
LTY           := $89
LTGT          := $8A       ; 0 = none
LSTEP         := $8B

HAS_AIM       := $8C       ; planning: an aim is picked and still stands
RANGE         := $8D       ; DrawRange: how far
N_SHIPS       := $8E       ; ships in this battle
SHOOT         := $8F       ; laser maths: the shooter
DIRX          := $90       ; scaled direction (signed, under 64 in size)
DIRY          := $91
LEN           := $92       ; its length
BEST          := $93       ; nearest ship on the beam, or $FF
BESTDOT       := $94       ; 2 bytes
VX            := $96       ; 2 bytes: target - shooter
VY            := $98       ; 2 bytes
DOT           := $9A       ; 2 bytes
CROSS         := $9C       ; 2 bytes
REDRAW        := $9E       ; beams need drawing this tick
EXTRA         := $9F       ; ticks run past the end of the turn
PATTR         := $A0       ; the canvas: attribute for tiles drawn now
PFILL         := $A1       ; 1 to start each new tile filled with value 3
DIGITS        := $A2       ; 3 characters and a terminator

AREA_X        := $A6       ; a blast's center
AREA_Y        := $A7
DSQ           := $A8       ; 2 bytes: a ship's distance from it, squared
MN_OWNER      := $AA       ; mines and blasts
MN_I          := $AB
MN_HIT        := $AC
MN_COUNT      := $AD
MN_FREE       := $AE
MN_OLD        := $AF
HD_C1         := $B0       ; HexDist: the two hexes
HD_R1         := $B1
HD_C2         := $B2
HD_R2         := $B3
HD_Q          := $B4
HD_DR         := $B5
HD_S          := $B6
RC            := $B7       ; loops over the board
RR            := $B8
MN_AGE        := $B9
FX_I          := $BA
FX_OFF        := $BB
FX_N          := $BC
SW_OLD        := $BD       ; SwapWeapon: was a jump picked?
FX_KIND       := $BE       ; 1 if the ring being added is a blast
RANK          := $BF       ; where a new score goes in the table
HDX           := $C0       ; HeadingOf: 2 bytes each, signed
HDY           := $C2
HG_AX         := $C4
HG_AY         := $C5
HG_S          := $C6
SD_DX         := $C7       ; ScaleDir: 2 bytes each, signed
SD_DY         := $C9
SD_AX         := $CB
SD_AY         := $CC
SD_NX         := $CD       ; 1 if negative
SD_NY         := $CE
NT_V          := $CF       ; NumToText
HPL_SHIP      := $D0       ; DrawHpLine
HPL_W         := $D2
S_A           := $D1       ; the sound driver's own: it runs in the interrupt
S_P           := $D3       ; 2 bytes
S_B           := $D9
S_C           := $DA
TI            := $D5       ; turn loops: outer ship
TJ            := $D6       ; inner ship
SND_LASER     := $D7       ; laser sound playing
MTMP          := $D8
MUL1          := $DB
MUL2          := $DC
MSIGN         := $DD
MAGB          := $DE
SQ_R          := $DF
SQ_BIT        := $E0
SQ_T          := $E1
HC_T          := $E2
ANY           := $E3
RND           := $E4       ; 2 bytes: random numbers
MODE          := $E6       ; the kind of battle (M_*)
AI_PHASE      := $E7       ; the CPU's thinking (ai.asm)
AI_Q          := $E8
AI_R          := $E9
AI_N          := $EA       ; places the enemy may end
AI_BEST       := $EB
AI_BC         := $ED       ; the best move so far
AI_BR         := $EE
AI_BW         := $EF       ; the best weapon
AI_BAC        := $F0       ; the best aim
AI_BAR        := $F1
AI_SC         := $F2       ; 2 bytes: this shot's score
AI_SX         := $F4       ; the ship's start, pixels
AI_SY         := $F5
AI_FX         := $F6       ; the enemy, pixels
AI_FY         := $F7
AI_LX         := $F8       ; the scaled line between them
AI_LY         := $F9
AI_LL         := $FA
AI_I          := $FB
AI_K          := $FC
AI_S          := $FD
AI_CNT        := $FE
AI_TMP        := $FF

; --- RAM: per-ship arrays, 4 bytes each, from $0800 ---
SHIP_FACTION  = $0800
SHIP_ROW      = $0804      ; palette row for its sprites
SHIP_INK      = $0808      ; layer 1 color for its text and beams
SHIP_ALIVE    = $080C
SHIP_HP_LO    = $0810      ; hull in 1/256 points
SHIP_HP_HI    = $0814
SHIP_C        = $0818      ; current hex
SHIP_R        = $081C
SHIP_HEAD     = $0820      ; heading 0..11
PLAN_C        = $0824      ; where it moves
PLAN_R        = $0828
AIM_C         = $082C      ; where it fires
AIM_R         = $0830
PLAN_WEAPON   = $0834
POS_X_LO      = $0838      ; replay position, 8.8 pixels
POS_X_HI      = $083C
POS_Y_LO      = $0840
POS_Y_HI      = $0844
VEL_X_LO      = $0848
VEL_X_HI      = $084C
VEL_Y_LO      = $0850
VEL_Y_HI      = $0854
TORP_ON       = $0858
TORP_X_LO     = $085C
TORP_X_HI     = $0860
TORP_Y_LO     = $0864
TORP_Y_HI     = $0868
TORP_VX_LO    = $086C
TORP_VX_HI    = $0870
TORP_VY_LO    = $0874
TORP_VY_HI    = $0878
TORP_FLASH    = $087C      ; ticks left of a torpedo's hit flash
BEAM_DX       = $0880      ; last beam direction
BEAM_DY       = $0884
BEAM_TGT      = $0888
EXPL_T        = $088C      ; explosion tick, 0 = none
HP_SHOWN      = $0890      ; hull last drawn on the panel
AIM_X         = $0894      ; aim point, pixels
AIM_Y         = $0898
FIRING        = $089C      ; firing a laser this turn


LINEBUF       = $08E0      ; a line of text being built (up to 16 + end)
GLYPH         = $08F8      ; 8 rows of a character

; --- The CPU's working memory ---
AI_EC         = $0900      ; places the enemy may end: column, row, weight, pixels
AI_ER         = $0908
AI_EW         = $0910
AI_EPX        = $0918
AI_EPY        = $0920
AI_TX         = $0928      ; the enemy at 3 moments for each of those (x)
AI_TY         = $0940      ; (y)
AI_PX         = $0958      ; the CPU's ship at the 3 moments
AI_PY         = $095B
AI_HC         = $0960      ; HexStep
AI_HR         = $0961
AI_HQ         = $0962
AI_HS         = $0963
AI_OC         = $0964
AI_OR         = $0965
AI_A          = $0966      ; Interp, SetV
AI_B          = $0967
AI_F          = $0968
AI_DX         = $0969      ; where the ship is going, pixels
AI_DY         = $096A
AI_AX         = $096B      ; the aim being tried
AI_AY         = $096C
AI_W          = $096D      ; the weapon being tried
AI_BURN       = $096E
AI_SUB        = $0973      ; which part of the shot is being scored
AI_BS_LO      = $0974      ; each weapon's best score and aim
AI_BS_HI      = $0976
AI_BA_C       = $0978
AI_BA_R       = $097A
AI_STAYED     = $097C      ; the enemy didn't move last turn

AI_KC         = $097D      ; where it knows the enemy to be
AI_KR         = $097E
AI_D          = $097F      ; how far that is

; --- Specials, 4 bytes a ship ---
SPECIAL_WAIT  = $0980      ; turns until it can be used again
PLAN_SPECIAL  = $0984      ; 1 if this turn's plan uses it
CLOAKED       = $0988      ; unseen by the other ship
SEEN_C        = $098C      ; where the other ship last saw it
SEEN_R        = $0990
JUMPING       = $0994      ; gone until it lands
ON_FIELD      = $0998      ; can be touched: alive and not mid-jump
; 6 mines
MINE_OWNER    = $0C60      ; its ship + 1, 0 = none
MINE_C        = $0C6C
MINE_R        = $0C78
MINE_X        = $0C84
MINE_Y        = $0C90
MINE_ARM      = $0C9C      ; the tick it arms
MINE_TURN     = $0CA8      ; when it was laid
; Seats
SEAT_KIND     = $0CB4      ; each ship in the battle: who flies it (KIND_*)
SHIP_SIDE     = $0CB8      ; its team, or itself
PREV_C        = $0CBC      ; where it was a turn ago
PREV_R        = $0CC0
STAYED        = $0CC4      ; it didn't move last turn
HUMANS        = $0CC8      ; people in this battle
HUMAN_SEAT    = $0CC9      ; one of them
TICK_MARK     = $0CCA      ; turn playback: the sound tick last waited for
BEAM_N        = $0CCB      ; beams burning
PLANNED       = $0CCC      ; the CPU has already chosen this ship's move
CFG_KIND      = $0CD0      ; the setup screen's four seats: who flies each
CFG_FAC       = $0CD4      ; and its faction
SEAT_SHIP     = $0CD8      ; a seat's ship in the battle, or $FF if it's off
SHIP_SEAT     = $0CDC      ; a ship's seat
; Blast rings
FX_T          = $09D0      ; ticks old, 0 = none
FX_X          = $09D4
FX_Y          = $09D8
FX_INK        = $09DC
; The CPU's specials
FX_BOOM       = $09E8      ; 1 for a blast, with a fireball in the ring
AI_SPEC       = $09E0      ; it will use its special
AI_FS         = $09E1      ; the best flak hex's score
AI_FC         = $09E2      ; and the hex
AI_FR         = $09E3
AI_HIDDEN     = $09E4      ; the enemy is cloaked
AI_TMP2       = $09E5
AI_ME         = $09EC      ; the seat being thought for
AI_FOE        = $09ED      ; the enemy it's watching
AI_MATE       = $09EE      ; its teammate, or $FF
AI_EASY       = $09EF
AI_MC         = $09F0      ; its hex, hull, faction and recharge
AI_MR         = $09F1
AI_MHP        = $09F2
AI_MFAC       = $09F3
AI_MWAIT      = $09F4
AI_FHP        = $09F5      ; the enemy's hull
AI_BAD        = $09F6      ; this shot would hit the teammate
AI_MTC        = $09F7      ; where the teammate will be
AI_MTR        = $09F8
AI_MX         = $09F9      ; it at the 3 moments
AI_MY         = $09FC

SPR_Y         = $0A00      ; sprite attributes, uploaded each frame
SPR_X         = $0A40
SPR_N         = $0A80
SPR_A         = $0AC0

; --- The high scores ---
SAVE_CODE     = $0B00      ; the flash routine runs here
SAVE_BUF      = $0C00      ; the table, as a save record
NAME_BUF      = $0C40      ; 3 letters
NEW_SCORE     = $0C44      ; 2 bytes

; --- The serial link ---
RX_BUF        = $0D00      ; 256 bytes, filled by the interrupt
RX_HEAD       = $0E00
RX_TAIL       = $0E01
OLD_IRQ       = $0E02      ; 2 bytes: the Kernal's interrupt handler
LINK_ON       = $0E04
MY_SEAT       = $0E05
MY_FACTION    = $0E06
TITLE_F       = $0E07      ; 2 bytes: the title's two factions
MY_NONCE      = $0E09      ; 2 bytes: picks who sits where
PEER_NONCE    = $0E0B      ; 2 bytes
PEER_FACTION  = $0E0D
HAVE_HELLO    = $0E0E      ; heard the other machine
PEER_HAS      = $0E0F      ; it has heard this one
LINK_T        = $0E10      ; frames until the next try
LINK_N        = $0E11
PARSE_N       = $0E12      ; bytes of the frame coming in
LINK_UP       = $0E13      ; the battle has started
LINK_BAD      = $0E14      ; why the link can't go on
HAVE_PLAN     = $0E15      ; this turn's plan has arrived
PEER_ACK      = $0E16      ; the other machine has ours
PEER_PLAN     = $0E17      ; 5 bytes
LINK_S        = $0E1C      ; the serial status being looked at
CK_A          = $0E1D      ; a frame's check
CK_B          = $0E1E
FRAME         = $0E20      ; 11 bytes coming in
TX_FRAME      = $0E30      ; 11 bytes going out

; --- The sound driver (sound.asm) ---
GPIO_INT_T2   = %00100000  ; the VIA's timer 2 interrupt
S_REG         = $0F00      ; the SID's registers, as they'll be written each tick
S_RTG         = $0F19      ; counts each voice's restarts
S_PEND        = $0F1C      ; a voice to restart this tick
S_Q           = $0F20      ; 8 requests from the game
S_QH          = $0F28
S_QT          = $0F29
S_BUSY        = $0F2A
MUS_ID        = $0F2B      ; the tune playing
MUS_WANT      = $0F2C      ; the tune asked for
MUS_ON        = $0F2D
M_LFO         = $0F2E      ; 2 bytes
F_ENV         = $0F30
S_ON          = $0F31
S_MASTER      = $0F32
S_TICKS       = $0F33      ; 2 bytes
M_PL          = $0F35      ; tracks, 3 bytes each
M_PH          = $0F38
M_SL          = $0F3B
M_SH          = $0F3E
M_LEFT        = $0F41
M_GATE        = $0F44
M_RATE        = $0F47
M_FILT        = $0F4A
SF_ID         = $0F4D      ; each voice's effect
SF_P          = $0F50
SF_PL         = $0F53
SF_PH         = $0F56
SF_LEFT       = $0F59
SF_FL         = $0F5C
SF_FH         = $0F5F
SF_TL         = $0F62
SF_TH         = $0F65
SF_FLG        = $0F68
S_FXC         = $0F6B      ; an effect's filter cutoff
S_FXK         = $0F6C      ; how fast it closes
SF_FIL        = $0F6D      ; 3 bytes: this voice's effect uses the filter
S_VARS_END    = $0F70

; --- The canvas: layer 1 cells drawn on pixel by pixel ---
CELLMAP       = $1000      ; 40 x 30: a cell's pool tile + 1 (0 = none)
CT_ROWS       = $2000      ; pool tiles' pixels: 16 pages, one for each byte of a tile
POOL_HI       = $0FF0      ; the highest pool tile in use
HI_SET        = $0FF1      ; CanvasFlush has found it
TILE_STATE    = $1C00      ; 0 free, 1 stale, 2 drawn, 3 drawn and new
TILE_LO       = $1D00      ; its cell, as an address in CELLMAP
TILE_HI       = $1E00
TILE_ATTR     = $1F00
