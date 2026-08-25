#!/usr/bin/env sh
set -eu

# Build sqlite_ffi for the current platform.
#
# Modes:
#   --system    Link against system sqlite3 (-lsqlite3)
#   --vendored  Build from sqlite amalgamation (sqlite3.c/sqlite3.h)
#
# Vendored layout expected by default:
#   third_party/sqlite/sqlite3.c
#   third_party/sqlite/sqlite3.h

MODE="system"
SQLITE_DIR="third_party/sqlite"
OUT_DIR="."

while [ $# -gt 0 ]; do
  case "$1" in
    --system)
      MODE="system"
      ;;
    --vendored)
      MODE="vendored"
      ;;
    --sqlite-dir)
      SQLITE_DIR="$2"
      shift
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--system|--vendored] [--sqlite-dir DIR] [--out-dir DIR]" >&2
      exit 2
      ;;
  esac
  shift
done

OS="$(uname -s)"
case "$OS" in
  Darwin) EXT="dylib" ;;
  Linux) EXT="so" ;;
  MINGW*|MSYS*|CYGWIN*) EXT="dll" ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 2
    ;;
esac

OUT="$OUT_DIR/sqlite_ffi.$EXT"

if [ "$MODE" = "vendored" ]; then
  if [ ! -f "$SQLITE_DIR/sqlite3.c" ] || [ ! -f "$SQLITE_DIR/sqlite3.h" ]; then
    echo "Missing sqlite amalgamation in $SQLITE_DIR" >&2
    echo "Expected files: sqlite3.c and sqlite3.h" >&2
    echo "Tip: fetch from https://github.com/sqlite/sqlite or sqlite.org amalgamation release." >&2
    exit 2
  fi
  cc -shared -fPIC -O2 -I ffi -I "$SQLITE_DIR" -DFLARIS_SQLITE_AMALGAMATION \
    -o "$OUT" ffi/sqlite_ffi.c
else
  cc -shared -fPIC -O2 -I ffi -o "$OUT" ffi/sqlite_ffi.c -lsqlite3
fi

echo "Built $OUT"
