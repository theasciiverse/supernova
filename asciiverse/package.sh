#!/bin/sh
# Packs the build into dist/supernova-<target>.tar.gz (.zip for Windows)
# for av: the program at the top with its data files beside it (it finds
# them there), README.md, PATCHES.md, the game's INSTRUCT.TXT and the
# licences.
#
#   asciiverse/package.sh x86_64-unknown-linux-musl
set -eu
cd "$(dirname "$0")/.."
target="$1"
case "$target" in *windows*) exe=.exe ;; *) exe= ;; esac
stage=stage/supernova
rm -rf "$stage" && mkdir -p "$stage" dist
cp "out/supernova$exe" "$stage/"
cp src/R1 src/R2 src/S1 src/L1 src/C1 src/SM src/B1 "$stage/"
cp README.md PATCHES.md INSTRUCT.TXT gpl-3.0.txt agpl-3.0.txt "$stage/"
if [ -n "$exe" ]; then
  (cd "$stage" && zip -qr "../../dist/supernova-$target.zip" .)
else
  tar -czf "dist/supernova-$target.tar.gz" -C "$stage" .
fi
ls dist
