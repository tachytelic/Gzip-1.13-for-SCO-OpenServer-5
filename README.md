# GNU gzip 1.13 for SCO OpenServer 5

A build of [GNU gzip 1.13](https://www.gnu.org/software/gzip/)
(August 2023) for **SCO OpenServer 5**. It is one 88 KB binary that
needs nothing but the system C library, and it is published as a plain
file rather than an archive, so a system with no gzip at all can fetch
it and use it straight away.

```
$ gzip --version
gzip 1.13

$ gunzip -c sed-4.8-sco.tar.gz | tar xf -    # unpack a release with the system tar
$ gzip -k backup.tar                         # compress and keep the original
$ zcat notes.gz | more
```

## Why?

Nearly everything built for these systems is shipped as a `.tar.gz`,
so gzip is the tool you need before you can unpack anything else.

- **OpenServer 5.0.5** has `compress` and `tar` but no gzip. The usual
  answer is Skunkware's package of gzip 1.2.4, from 1993, installed
  with `custom`.
- **OpenServer 5.0.7** has gzip 1.3.5, from 2002.

This one is a single file to copy into place. Over the old versions it
adds `-k` to keep the original file, and thirty years of fixes, among
them to the handling of damaged archives and to `zgrep`.

It does not compress better or faster. The format has not changed, and
in my tests the same file came out the same size to the byte from
1.2.4, 1.3.5 and 1.13. Each version reads what the others write.

## Requirements

| System | Needs |
|---|---|
| OpenServer 5.0.7 | Nothing extra on the system it was built and tested on. |
| OpenServer 5.0.5 | OSS646C, the Execution Environment Supplement. |
| OpenServer 5.0.6 | Not tested. |

On 5.0.5 the binary needs the C library that OSS646C installs. The one
on the install CD, and the one from RS505A, lack five routines it calls
(`__fpclassifyl`, `fsync`, `ftello`, `gettimeofday` and
`___requires_updated_system_library_set___`). That is the same
supplement our curl build needs, so gzip goes on straight after curl.

## Install

> **Fresh SCO box?** Install [curl with TLS](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
> first, or copy the file across by FTP in binary mode. The full set of
> builds is listed at
> [scoexpert.com](https://scoexpert.com/guides/sco-openserver-5-binaries/).

```sh
# On the SCO box:
curl -Lo /usr/local/bin/gzip https://github.com/tachytelic/Gzip-1.13-for-SCO-OpenServer-5/releases/download/v1.0.0/gzip
chmod 755 /usr/local/bin/gzip
ln /usr/local/bin/gzip /usr/local/bin/gunzip
ln /usr/local/bin/gzip /usr/local/bin/zcat
gzip --version
```

gzip looks at the name it was started by, so the two links are all it
takes to have `gunzip` and `zcat`.

On 5.0.5, also link it into `/bin`, where 5.0.7 keeps its gzip and
where our GNU tar build looks for it:

```sh
ln -s /usr/local/bin/gzip /bin/gzip
ln -s /usr/local/bin/gzip /bin/gunzip
```

On 5.0.7 leave `/bin/gzip` alone. It belongs to the system. Put
`/usr/local/bin` ahead of `/bin` in `PATH` if you want this one first.

### The full package

`gzip-1.13-sco.tar` is a plain tar of the same binary with the helper
scripts (`zgrep`, `zdiff`, `zcmp`, `zmore`, `zless`, `zforce`, `znew`,
`gzexe`) and the man pages. Unpack it over `/usr/local` with the system
tar:

```sh
curl -LO https://github.com/tachytelic/Gzip-1.13-for-SCO-OpenServer-5/releases/download/v1.0.0/gzip-1.13-sco.tar
cd /usr/local && tar xf /path/to/gzip-1.13-sco.tar
```

The scripts run under `/bin/ksh`, which every OpenServer 5 system has.
`zless` needs `less`, which a stock system does not have.

### Checksums

`sum -r` is the one a bare system can run.

| File | Bytes | `sum -r` | SHA-256 |
|---|---|---|---|
| `gzip` | 87,784 | `23370 172` | `2691fd5277b6568f5b834970304b9379f14aea30d6275c3ffe6d737bd698c937` |
| `gzip-1.13-sco.tar` | 221,696 | `56683 433` | `400bbdce1024e8b32c6eec9747d5a76a265003fc96e2fb6db5978fa15d47531e` |

## What was tested

On OpenServer 5.0.7, where it was built:

- gzip's own test suite: 28 tests, 23 pass, 3 are skipped and 2 fail.
  Neither failure is in the binary. `list-big` needs a 4 GB file, and
  an OpenServer 5 filesystem stops at 2 GB. `pipe-output` runs eight
  commands into a closed pipe and seven behave as it expects; the
  eighth, the `zgrep` script, returns 0 when the pipe signal is being
  ignored. The skips are for no `/dev/urandom`, for running as root,
  and for the system `grep` having no context options.
- Text and binary files packed by this build and unpacked by the
  system's gzip 1.3.5, and the other way round: identical.
- A 2.2 GB stream and a 4.4 GB stream through `gzip -1 | gzip -dc`,
  compared byte for byte with the original: identical, no warnings.

On OpenServer 5.0.5 with RS505A, OSS497C, OSS640A, OSS642A and OSS646C:

- The same exchange with Skunkware's gzip 1.2.4, both ways: identical.
- One of our release tarballs unpacked by both: identical.
- GNU tar reading and writing through it; the system tar reading from
  it through a pipe.
- `gunzip`, `zcat` and `uncompress` as links, including on a `.Z` file
  made by `compress`.
- `zgrep`, `zegrep`, `zfgrep`, `zcmp`, `zdiff`, `zforce`, `znew`,
  `zmore` and `gzexe`.

## Building from source

On a 5.0.7 system with GCC, bash and GNU make:

```sh
cd gzip-sco
./build.sh
```

Or with a non-default GCC, and with the test suite:

```sh
CHECK=1 GCC=/usr/local/bin/gcc-3.4.6 ./build.sh
```

It leaves the files under `install/usr/local` and the two release
files in `prebuilt/`.

### What the patch does

`patches/gzip-1.13-sco.patch` is a 22-line diff with two hunks in
gnulib, the same two as our other gnulib-based builds (tar, coreutils,
grep, sed, findutils):

1. **`lib/unistd.in.h`**: skip gnulib's `gethostname` redeclaration,
   which clashes with SCO's older `int len` prototype.
2. **`lib/getprogname.c`**: replace the `#error` for unrecognised
   systems with a `return "?"` fallback.

### What the build script does beyond that

- **`-DGNU_STANDARD=0`** keeps gzip's old habit of acting on its own
  name. Without it `gunzip` and `zcat` are shell scripts, and the
  binary could not stand in for them through a link.
- **`gunzip`, `zcat` and `uncompress` are hard links** to the binary
  in the package, not scripts, so they need no shell.
- **The remaining scripts are pointed at `/bin/ksh`.** As built they
  carry the path of the bash that ran `configure`, which a target
  system may not have.

The patch applies to gzip 1.12 and 1.13. It does not apply to 1.14,
which is why this is 1.13.

## Repository layout

```
patches/
  gzip-1.13-sco.patch          22 lines, 2 hunks
build.sh                       Native-build script (run on SCO)
LICENSE                        MIT (covers patch + build script)
README.md                      This file
```

The binary and the tar ship via the **[Releases](../../releases)**
page.

## License

GNU gzip is © Free Software Foundation, distributed under
[GPLv3+](https://www.gnu.org/licenses/gpl-3.0.html). The prebuilt
binary is unmodified upstream gzip 1.13 with the patch in this repo
applied. The patch and build script are released under MIT.

## See also

- [curl-7.88.1 for SCO](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5):
  the natural first install on a fresh SCO box.
- [GNU tar 1.34 for SCO](https://github.com/tachytelic/Tar-1.34-for-SCO-OpenServer-5):
  the other half of unpacking a `.tar.gz`.
- [More SCO OpenServer 5 binaries](https://scoexpert.com/guides/sco-openserver-5-binaries/):
  the full list of builds, on scoexpert.com.
- [SCO Expert](https://scoexpert.com/): support for SCO OpenServer
  systems, with guides, a knowledge base and a mirror of SCO's own
  downloads.
