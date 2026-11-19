# itch.io page

The settings and text for HexFleet's page on itch.io, on Jay's own account (Aaron's games go on his account, and games they make together on infinitetoken.itch.io). The page offers the cartridge as a download, and its description links to the version that plays in a browser at games.infinitetoken.com.

`description.md` is the page's Description. itch's editor is rich text, so copy it from a rendered preview (the app's file pane or GitHub) to bring its headings, bold and links along. Pasting the raw Markdown shows the `#`s and `**`s.

## Settings

| Field | Value |
| --- | --- |
| Title | HexFleet |
| Project URL | `jayrdeaton.itch.io/hexfleet` |
| Short description or tagline | Turn-based starship battles on a hex grid for the AC6502 ACE. Plan in secret, then every ship fires at once. |
| Classification | Games |
| Kind of project | Downloadable |
| Release status | In development: nobody but Jay has played it, and the save and serial code hasn't run on a real ACE. Change it to Released once both have happened. |
| Pricing | No payments to start. $0 or donate can come later, once people have played it, and taking money means itch's payout and tax setup. |
| Uploads | `HexFleet.crt`, with the display name "HexFleet.crt (128 KB Flash Cart for the PICOVDP)". Leave the Windows, macOS, Linux and Android boxes unticked, since it's a cartridge image, not a build for any of them. |
| Description | `description.md` |
| Genre | Strategy |
| Tags | `6502`, `homebrew`, `retro`, `8-bit`, `turn-based-strategy`, `hex`, `space`, `sci-fi`, `local-multiplayer`, `tactical` (itch takes 10). Take itch's own spelling of each as it suggests them. |
| Generative AI disclosure | Yes, with Code: the game's code was written with Claude. Jay decides whether Graphics and Sound apply: the hull textures and the SID music and effects come from scripts written with Claude, though no image or audio generator was used. Answering No would add the No AI tag, and itch removes projects from browse when generative AI isn't disclosed. |
| Inputs | Keyboard, Joystick |
| Multiplayer | Local multiplayer, 1 to 4 players |
| Community | Comments, for bug reports and scores |
| Visibility | Draft until the page is filled in, then Public |

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

## Before it goes public

1. Make the itch account (`jayrdeaton`, display name Jay Deaton) and set its profile links to games.infinitetoken.com, jaydeaton.com and GitHub.
2. Answer the AI disclosure.
3. Fill in the settings above, paste the description, upload `HexFleet.crt`, `cover.png` and the screenshots, preview it as a draft, then set it to Public. A first page may wait in itch's review queue before it shows up in browse.
