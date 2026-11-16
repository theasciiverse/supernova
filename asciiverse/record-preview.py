#!/usr/bin/env python3
"""Records asciiverse/supernova.cast, the catalog preview, at 100x30
(hub/RECORDING.md): the title, the identity code, the miner's life on
Barre-An, the tavern's menu, a mug of glunk lite, and two alien miners
talking about a crystal worth millions, typed at a human pace, with a
throwaway HOME so a fresh game starts. Run after asciiverse/build.sh and
asciiverse/package.sh:
    python3 asciiverse/record-preview.py stage/supernova"""
import fcntl, json, os, pty, select, shutil, struct, sys, tempfile, termios, time

MOVES = [("look at menu", 3.5), ("buy glunk lite with coin", 3.5),
         ("sit at middle table", 2.0), ("z", 2.5), ("z", 3.0),
         ("listen carefully to aliens", 4.0), ("z", 5.0), ("z", 3.5)]

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
game_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else f"{root}/stage/supernova")
cast = f"{root}/asciiverse/supernova.cast"
home = tempfile.mkdtemp()
env = dict(os.environ, HOME=home, TERM="xterm-256color", LANG="C.UTF-8",
           USER="player", LOGNAME="player",
           PATH=game_dir + os.pathsep + os.environ.get("PATH", ""))
for k in ("XDG_STATE_HOME", "NO_COLOR", "SUPERNOVA_LOG"):
    env.pop(k, None)

pid, fd = pty.fork()
if pid == 0:
    os.execvpe("asciinema", ["asciinema", "rec", "--overwrite", "-q", "-i", "2",
        "--window-size", "100x30", "--capture-env", "TERM,LANG",
        "--title", "Supernova", "-c", "supernova", cast], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))


def pump(t):
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.03)
        if r:
            try:
                os.read(fd, 65536)
            except OSError:
                return


def type_line(line, after):
    for c in line:
        os.write(fd, c.encode()); pump(0.09)
    os.write(fd, b"\r"); pump(after)


pump(3.0)                       # the title screen
os.write(fd, b" "); pump(1.5)
type_line("ZED", 8.0)           # the identity code, then the opening
for move, after in MOVES:
    type_line(move, after)
type_line("quit", 1.5)
os.write(fd, b"y"); pump(3.0)
for _ in range(50):
    if os.waitpid(pid, os.WNOHANG)[0]:
        break
    time.sleep(0.2)
shutil.rmtree(home, ignore_errors=True)

# asciinema writes the command it ran into the header; players never use
# it, so it is taken out
with open(cast) as f:
    lines = f.read().split("\n")
head = json.loads(lines[0])
head.pop("command", None)
lines[0] = json.dumps(head, separators=(",", ":"))
with open(cast, "w") as f:
    f.write("\n".join(lines))
print(cast, os.path.getsize(cast), "bytes")
