#!/bin/sh
# Build GNU gzip 1.13 natively on SCO OpenServer 5.0.7.
#
# Output, under ./install/usr/local:
#   bin/gzip                      the one binary
#   bin/gunzip, zcat, uncompress  hard links to it
#   bin/z*, bin/gzexe             helper scripts, run by /bin/ksh
#   share/man/man1                man pages
# and, under ./prebuilt:
#   gzip                          the binary on its own
#   gzip-1.13-sco.tar             everything above, as a plain tar
#
# -DGNU_STANDARD=0 keeps gzip's old habit of acting on its own name, so the
# one binary also works as gunzip or zcat through a link. That is what lets
# it be published as one plain file: a system with no gzip at all can fetch
# it with curl and needs nothing to unpack it.
#
# Set CHECK=1 to run gzip's own test suite after the build.

set -e

SCRIPT_DIR=`cd \`dirname "$0"\` && pwd`
VERSION=1.13
TARBALL=gzip-${VERSION}.tar.gz
SRCDIR=gzip-${VERSION}
PREFIX=/usr/local
DEST="$SCRIPT_DIR/install"

CC="${GCC:-${CC:-gcc}}"
export CC
PATH=/usr/gnu/bin:/usr/ccs/bin:/usr/bin:/bin:/usr/local/bin
export PATH

if [ ! -f "$TARBALL" ]; then
    if which wget >/dev/null 2>&1; then
        wget --no-check-certificate "https://ftp.gnu.org/gnu/gzip/${TARBALL}"
    elif which curl >/dev/null 2>&1; then
        curl -kLO "https://ftp.gnu.org/gnu/gzip/${TARBALL}"
    else
        echo "ERROR: drop $TARBALL next to this script" >&2; exit 1
    fi
fi

if [ ! -d "$SRCDIR" ]; then
    gunzip -c "$TARBALL" | /usr/bin/tar xf -
fi

cd "$SRCDIR"

if [ ! -f .sco_patched ]; then
    echo "Applying SCO compatibility patch..."
    /usr/bin/patch -p1 < "$SCRIPT_DIR/patches/gzip-${VERSION}-sco.patch"
    touch .sco_patched
fi

SHELL_BIN=`which bash 2>/dev/null`
[ -n "$SHELL_BIN" ] || SHELL_BIN=/usr/local/bin/bash
if [ ! -x "$SHELL_BIN" ]; then
    echo "ERROR: bash required as configure shell." >&2; exit 1
fi

echo "Configuring..."
FORCE_UNSAFE_CONFIGURE=1 CONFIG_SHELL=$SHELL_BIN $SHELL_BIN configure \
    --prefix="$PREFIX" \
    CC="$CC" \
    CFLAGS="-O2 -std=gnu99 -DGNU_STANDARD=0"

# The patch modifies lib/unistd.in.h; force regeneration of lib/unistd.h.
rm -f lib/unistd.h

echo "Compiling..."
gmake

# The helper scripts are given the shell that ran configure, which is bash:
# as their first line and, in gzexe, in the header it writes onto every file
# it packs. Every OpenServer 5 system has ksh; few have bash.
MAKE_SHELL=`sed -n 's/^SHELL *= *//p' Makefile`
[ -n "$MAKE_SHELL" ] || MAKE_SHELL=$SHELL_BIN
for f in gunzip gzexe uncompress zcat zcmp zdiff zegrep zfgrep zforce zgrep zless zmore znew; do
    if [ -f "$f" ]; then
        sed "s|$MAKE_SHELL|/bin/ksh|g" "$f" > "$f.t"
        cat "$f.t" > "$f"
        rm -f "$f.t"
    fi
done

if [ "$CHECK" = 1 ]; then
    echo "Running the test suite..."
    gmake check || echo "Test suite reported failures: see tests/*.log"
fi

echo "Installing to $DEST$PREFIX ..."
rm -rf "$DEST"
gmake install DESTDIR="$DEST"

# The info index is the target system's own file, not ours to replace.
rm -f "$DEST$PREFIX/share/info/dir"

BIN="$DEST$PREFIX/bin"
strip "$BIN/gzip" 2>/dev/null || true

# gunzip, zcat and uncompress as links to the binary: they then need no
# shell at all, and work on a system that has nothing else installed.
for n in gunzip zcat uncompress; do
    rm -f "$BIN/$n"
    ln "$BIN/gzip" "$BIN/$n"
done

echo "Packaging..."
mkdir -p "$SCRIPT_DIR/prebuilt"
rm -f "$SCRIPT_DIR/prebuilt/gzip" "$SCRIPT_DIR/prebuilt/gzip-${VERSION}-sco.tar"
cp "$BIN/gzip" "$SCRIPT_DIR/prebuilt/gzip"
(cd "$DEST$PREFIX" && /usr/bin/tar cf "$SCRIPT_DIR/prebuilt/gzip-${VERSION}-sco.tar" bin share)

ls -l "$BIN" "$SCRIPT_DIR/prebuilt"
