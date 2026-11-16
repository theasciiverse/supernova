# Supernova

Fourteen hours a day in the core of some dusty, smelly mine on Barre-An,
and the mines are not as generous as they were. Then, over a mug of
glunk lite in the tavern on the edge of the colony, you overhear two
alien miners: an ancient crystal, worth millions of goolaas, on a ritual
planet far beyond the Sagan system. Your battered ship is waiting in the
parking lot. A star is dying somewhere out there, and a whole
civilization is running out of time.

Scott Miller's science-fiction text adventure, written with Terry Nagy
and published in 1987, before he founded Apogee. Type what you want to
do in plain English, several commands to a line: **open the hatch then
enter the ship**, or **aliens, can you tell me about the crystal**.

## Play

With [av](https://asciiverse.sh), the Asciiverse client:

```
av install supernova
av play supernova
```

- Type a command and press Enter; separate several with periods or THEN.
  INSTRUCT.TXT has the game's own instructions and the words it knows.
- The game's own keys: the arrows, Home, End, PgUp and PgDn walk in the
  eight directions (fore, aft, port and starboard aboard ship), Insert
  goes down and Delete up, F1 saves,
  F2 restores, F3 toggles room descriptions, F4 looks, F5 and F6 get and
  drop everything, F7 shows the score, F8 the inventory, F9 waits and F10
  repeats.
- **Shift+PgUp** and **Shift+PgDn** page back through the story.
- **SAVE** and **RESTORE** ask for a name (LIST shows the saved games).
  They are kept in `$XDG_STATE_HOME/supernova` (usually
  `~/.local/state/supernova`), or `%LOCALAPPDATA%\supernova` on Windows.
- **QUIT** ends the game, **RESTART** begins it again, **CLUE** gives a
  hint for a price.
- Set `NO_COLOR` (or start it with `/B`) for the game's black and white
  scheme, and `SUPERNOVA_LOG=1` to keep a log of the session in
  `supernova.log` in the state folder.

The game's framed screen fills the terminal, whatever its size (80x24 or
more), and the story is laid out again when the terminal is resized.

## Credits

Scott Miller wrote Supernova in Turbo Pascal from 1985, with the story by
him and Terry Nagy; it was published in 1987 as shareware, then sold by
Apogee Software. Apogee made it freeware in March 1998 and released its
source code under the GNU GPL (version 2 or later) on March 20, 2009. In
November 2014 Jason Self brought the source to Free Pascal so it builds
and runs on modern systems without an emulator
(https://jxself.org/supernova.shtml, https://jxself.org/git/supernova.git);
his history of the release is in `History/`.

Licence: the game is GPL-3.0-or-later (`gpl-3.0.txt`), Jason Self's
changes and ours are AGPL-3.0-or-later (`agpl-3.0.txt`), so the program
as a whole is AGPL-3.0-or-later.

This is the build for the Asciiverse catalog: the game is unchanged, and
what changed around it (the screen, saves, logging) is in PATCHES.md. To
build it yourself you need Free Pascal 3.2.2: `asciiverse/build.sh` makes
`out/supernova`, which looks for its data files (R1, R2, S1, L1, C1, SM
and B1, from `src/`) beside itself.
