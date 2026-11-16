# Changes from upstream

This is the Asciiverse packaging of Supernova, Scott Miller's text
adventure with the story by him and Terry Nagy (written from 1985,
published in 1987). Upstream is Jason Self's free-software revival,
https://jxself.org/git/supernova.git, the `upstream` remote: its first
commit is Apogee Software's source release of March 20, 2009
(GPL-2.0-or-later), and his commits of November 2014 bring it to Free
Pascal so it builds and runs on modern systems. This build is his
`master` at `dcdf2ef` (2014-11-21). Upstream names no version, so
releases here are tagged `v1.0+20141121-av.N`. The `asciiverse` branch
carries the changes below, one commit each.

Licence: Apogee released the game under GPL-2.0-or-later; Jason Self
took it to GPL-3.0-or-later (`gpl-3.0.txt`) and put his changes under
AGPL-3.0-or-later (`agpl-3.0.txt`), as permitted by section 13 of each
licence. Our changes are AGPL-3.0-or-later too, so the program as a
whole is AGPL-3.0-or-later.

## The game

Unchanged: the parser, the vocabulary, the rooms, characters, puzzles,
timers, scoring and every text, in `src/*.PAS` and the data files R1, R2,
S1, L1, C1, SM and B1, and the game's own keys (arrows, Home, End, PgUp
and PgDn for the eight directions, Insert and Delete for down and up, F1
to F10 for its commands). The resource editors and the installer
(ROOMRITE, LINERITE, SPECIAL, CLUERITE, CREATE, INSTALL) are not built.

## Ours

- **Any terminal, through avcrt, in place of ncurses, Crt and SDL.** The
  2014 version drew through FPC's ncurses Crt on Unix, refused any
  terminal that was not exactly 80x25, and played the PC speaker's tones
  as an SDL square wave. `src/avcrt.pas`, new and shared with our Beyond
  the Titanic, stands in for Turbo Pascal's Crt unit on every platform:
  the same calls drawn on a terminal of any size on Linux, macOS and
  Windows, the PC's characters (the frame's box lines, the » prompt) as
  UTF-8, its colours as ANSI colours, on the alternate screen, which is
  restored on exit. Text written to the story window is word-wrapped at
  its edge; rows that scroll off its top are kept, so the player can page
  back (Shift+PgUp, Shift+PgDn) and the story is laid out again at the
  new width when the terminal is resized. The game's own DOS drawing code
  is used everywhere, with the PC's 80 and 25 taken from the terminal:
  the frame, the status panel and the story window grow with it, and the
  title, identity, death and victory screens are placed for its size.
  The speaker is silent, so the waits that only timed a tone are left out
  (a tune keeps a tenth of each note as a beat), and the title's colour
  flicker waits 60 ms a turn instead of 1. The current folder's name no
  longer goes into a 29-character string, which failed the next write
  when the folder's path was longer. `NOVA.PAS`, `ADPAR.PAS`,
  `DEFAULT.PAS`.
- **The game's texts laid out to the width.** The descriptions and
  messages in R1/R2, S1 and L1 were laid out for the 78-column story
  window by padding lines with spaces, and some words met at the edge
  with no space between them. RR, RS and RL write them through
  AvShowText, which takes the padding out and keeps the breaks the author
  meant. The pictures and conversations in SM and B1 are written line by
  line as before. `ADPAR.PAS`.
- **Data beside the program, saves in the state folder.** The game opened
  its data files in the current folder, so it had to be started from
  `src`, and saved to a SAVE/RESTORE disk. It now finds the data beside
  the program, saying so plainly when it cannot, and keeps saved games in
  `$XDG_STATE_HOME/supernova`, else `~/.local/state/supernova` (Linux and
  macOS), or `%LOCALAPPDATA%\supernova` on Windows. SAVE and RESTORE ask
  for a name and act at once, without clearing the story window for a
  disk swap; names keep letters, digits, `-` and `_`; LIST lists the
  saved games there. The confirmation no longer cuts the first two
  letters off the name, and a name that is not saved says so plainly.
  The name prompt has line editing. RESTART, and starting a new game after
  a death, ran a second copy of the game from inside the first; now the
  game starts again in place of the running one. QUIT, and quitting after
  a death, leave the final score and Good-bye! on the terminal after the
  game's screen closes. `ADPAR.PAS`, `DEFAULT.PAS`, `NOVA.PAS`.
- **Colour without asking.** The game began by asking whether the screen
  was colour or black and white. It now plays in colour, or in its black
  and white scheme when `NO_COLOR` is set; `/B` and `/M` on the command
  line still choose black and white. `ADPAR.PAS`.
- **Session log behind `SUPERNOVA_LOG`.** Set it to anything and
  `supernova.log` in the state folder gets, appended, every key as it
  arrives, every command line, the story as it is written, the identity
  code name, each turn's move, score, room, region and condition, saves
  and restores, deaths, the win and resizes. Without it nothing is
  written. `NOVA.PAS`, `ADPAR.PAS`, `DEFAULT.PAS`, `avcrt.pas`.
- **A README.md** on playing it with av.

## Packaging (new files)

- `asciiverse/build.sh`: builds `out/supernova` with Free Pascal 3.2.2
  (`-Sg` for the game's gotos, stripped, smart-linked); the compiler and
  target flags come from the environment. Linux binaries are static.
- `asciiverse/package.sh`: lays out each av archive (the program, its
  seven data files, README.md, PATCHES.md, INSTRUCT.TXT and the two
  licences).
- `asciiverse/smoke.py`: plays a few turns in a 100x30 pseudo-terminal
  (title, identity code, first room, a move, a save, the log, QUIT); run
  on every Linux and macOS build.
- `asciiverse/supernova.cast` and `asciiverse/record-preview.py`: the
  catalog preview and the script that records it.
- `.github/workflows/release.yml`: builds, tests and releases all of it
  on a tag.
- `.gitignore`: build output of the above.
