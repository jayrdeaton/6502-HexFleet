# itch.io page

HexFleet's page on itch.io, https://jayrdeaton.itch.io/hexfleet, public since 2026-11-19 on Jay's own account (Aaron's games go on his account, and games they make together on infinitetoken.itch.io). The page offers the cartridge as a download, and its description links to the version that plays in a browser at games.infinitetoken.com.

`description.md` is the page's Description. itch's editor is rich text: paste the description as HTML in its source view (the `<>` button), or copy it from a rendered preview. Pasting the raw Markdown shows the `#`s and `**`s.

## Settings

| Field | Value |
| --- | --- |
| Title | HexFleet |
| Project URL | `jayrdeaton.itch.io/hexfleet` |
| Short description or tagline | Turn-based starship battles on a hex grid for the AC6502 ACE. Plan in secret, then every ship fires at once. |
| Classification | Games |
| Kind of project | Downloadable |
| Release status | Released |
| Pricing | $0 or donate, suggesting $3 like Wizards Lab. Payouts are collected by itch.io and paid later, with the tax interview done. |
| Uploads | `HexFleet.crt`, of type Other (not Executable: it's a cartridge image, not a build for Windows, macOS, Linux or Android), with its own name as the display name and no platform boxes ticked |
| Description | `description.md` |
| Genre | Strategy |
| Tags | `6502`, `homebrew`, `retro`, `8-bit`, `turn-based`, `hex-based`, `space`, `sci-fi`, `local-multiplayer`, `local-co-op` (itch takes 10). Local co-op is two people as teammates against CPUs. |
| Generative AI disclosure | Left unanswered: itch only requires it of asset creators, and it's optional for games. Never answer No: the code was written with Claude, itch counts LLM-written code as generative AI content, and it drops pages that answer falsely from search and browse. |
| App store links | None: the HexFleet app is a different game, and the description's More HexFleet section points to it |
| Custom noun | Blank (game) |
| Download & install instructions | See below |
| Community | Comments |
| Visibility | Public |
| Metadata tab | Average session a few minutes, English, Keyboard and Joystick, local multiplayer, 1 to 4 players |

## Download & install instructions

Pasted as HTML in the field's source view:

```html
<p>Play it in the <a href="https://github.com/acwright/6502-EMULATOR">AC6502 emulator</a>, 3.0 or newer, with the video card set to PICOVDP. Load HexFleet.crt as a cartridge, or from a terminal:</p>
<p><code>6502 run --vdp picovdp --cart HexFleet.crt</code></p>
<p>High scores are saved to HexFleet.sav beside the cartridge. On a real ACE, it needs a 6502-PICOVDP on BIOS 2.x and a 128 KB Flash Cart.</p>
<p>No emulator? Play it in your browser at <a href="https://games.infinitetoken.com/6502/hexfleet">games.infinitetoken.com</a>.</p>
```

## Theme

The cart's own colors, read from its screenshots:

| Setting | Value |
| --- | --- |
| BG and BG 2 | `#111122`, the board's navy, so the screenshots and cover blend into the page |
| Text | `#c8d2de`, the game's panel gray (`#99aabb`) lightened for reading |
| Link | `#00eeee`, the HEXFLEET wordmark's cyan |
| Font | Lato, Large |
| Banner | `banner.png`: the title screen's HEXFLEET wordmark at 4x on transparency, 960 x 164, centered. It takes the place of the page's title. |
| Background | `background.png`: one 20 x 30 tile of the board's hex grid (`#224466` on the navy) at 2x, repeated both ways |

## Images

- **Cover image:** `cover.png`, 630 x 500 (itch shows it at 315 x 250 in browse; search and browse only list a page that has one). Four ships trading lasers at close range on turn 6, with the title screen's HEXFLEET band laid over the same rows, so the grids line up. It's a 210 x 167 crop of the screen scaled up 3x.
- **Screenshots** (`screenshots/`, in upload order), each a 320 x 240 capture scaled up 3x with nearest-neighbor to 960 x 720, as Games-Web's are:
  1. `1-title.png`: the title screen, you against three CPUs, with the Vanguard's special described
  2. `2-planning.png`: a turn planned, with the move outlined, the target picked and Lock In? showing
  3. `3-battle.png`: all four ships at close range with lasers crossing
  4. `4-jump.png`: the Wraith gone mid-jump, its landing ring showing
  5. `5-explosion.png`: the Raider blowing up while the Swarm's laser burns the Wraith

  The battle shots are from an all-CPU battle. There's no high score shot: the table is empty until a person beats the CPUs.
- **Retaking them:** run the emulator headless with its debug server (3.0 or newer, `~/Developer/.tooling/6502-EMULATOR` built with `npm run build:cli`), drive it with `dbg input joystick` and `dbg runcycles`, and save frames with `dbg screen png`.

## Keeping it in step

When the cartridge is rebuilt, upload the new `HexFleet.crt` here and move the cart's pinned commit in Games-Web's `src/constants/site.ts` at the same time, so the download and the browser version are the same build. A rebuilt cartridge won't load a save from an older build, and linked machines need the same build.
