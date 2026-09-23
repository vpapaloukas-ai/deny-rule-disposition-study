#!/usr/bin/env python3
"""repack-tarballs.py - clear owner fields from archive headers without changing what they hold.

  usage: repack-tarballs.py <archive-dir> <manifest>            re-pack every *.tar.gz in place
         repack-tarballs.py --check <archive-dir> <manifest>    verify archives against a manifest

WHY. A tar header names the account that packed the archive, as user and group names and as
numeric ids. The scrub rewrites file contents and never touches headers: every member of the
transcript archives in the bundle carried a non-root owner (measured 2026-09-17). Re-scrubbing
would rewrite contents the archives have already shipped with. Re-packing does not: same members,
same order, same names, types, modes, mtimes, link targets and bytes; owner and group 0 with no
names; a gzip header with no file name and no timestamp.

WHAT IS ASSERTED before any original is replaced, for every archive:
  - the new member list equals the old one, in order, in every field named above;
  - each regular file's SHA-256 is equal before and after;
  - every member's owner is 0/0 with empty names.
All archives are re-packed and verified first, and only then are the originals replaced. If any
archive fails, none is replaced, no temporary file is left, and the exit status is 1.

The manifest records, per member, the SHA-256 before and after, and per archive the SHA-256 of
the whole file before and after. --check re-reads the archives and verifies member digests,
owners and whole-file digests against it. It cannot reproduce the archives as they were before
re-packing: only the private record's history holds those.

--check also lists the archive directory and fails on any *.tar.gz that the manifest does not
name, because a verifier that reads only its own manifest cannot report a file it has not seen.
"""
import copy
import datetime
import gzip
import hashlib
import os
import sys
import tarfile

NEUTRAL_PAX_KEYS = ("uid", "gid", "uname", "gname")


class RepackError(Exception):
    pass


def kind(m):
    return ("file" if m.isfile() else "dir" if m.isdir() else "symlink" if m.issym()
            else "hardlink" if m.islnk() else "other")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def describe(tf):
    """Every member, in archive order: (name, kind, mode, mtime, size, linkname, sha256 or None)."""
    out = []
    for m in tf.getmembers():
        digest = None
        if m.isfile():
            fh = tf.extractfile(m)
            if fh is None:
                raise RepackError(f"{m.name}: regular file with no data")
            h = hashlib.sha256()
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
            digest = h.hexdigest()
        out.append((m.name, kind(m), m.mode, int(m.mtime), m.size, m.linkname, digest))
    return out


def owners_neutral(tf):
    return all(m.uid == 0 and m.gid == 0 and m.uname == "" and m.gname == "" for m in tf.getmembers())


def tar_format(path):
    """Keep the header format the archive was written in: GNU, or POSIX for anything else."""
    with gzip.open(path, "rb") as fh:
        head = fh.read(512)
    return tarfile.GNU_FORMAT if head[257:265] == b"ustar  \x00" else tarfile.PAX_FORMAT


def repack_to(src_path, tmp_path):
    fmt = tar_format(src_path)
    with tarfile.open(src_path, "r:gz") as src:
        before = describe(src)
        with open(tmp_path, "wb") as raw, \
                gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0, compresslevel=9) as gz, \
                tarfile.open(fileobj=gz, mode="w", format=fmt) as dst:
            for m in src.getmembers():
                info = copy.copy(m)
                info.pax_headers = {k: v for k, v in m.pax_headers.items() if k not in NEUTRAL_PAX_KEYS}
                info.uid, info.gid, info.uname, info.gname = 0, 0, "", ""
                dst.addfile(info, src.extractfile(m) if m.isfile() else None)
    with tarfile.open(tmp_path, "r:gz") as new:
        after = describe(new)
        neutral = owners_neutral(new)
    if after != before:
        raise RepackError("member list, fields or contents changed")
    if not neutral:
        raise RepackError("owner fields not cleared")
    return before


def repack_all(archive_dir, manifest):
    names = sorted(n for n in os.listdir(archive_dir) if n.endswith(".tar.gz"))
    if not names:
        print("🔴 no .tar.gz archives found - nothing to re-pack")
        return 1
    staged, temps, current = [], [], ""
    try:
        for current in names:
            path = os.path.join(archive_dir, current)
            tmp = path + ".repack-tmp"
            temps.append(tmp)
            members = repack_to(path, tmp)
            staged.append((current, path, tmp, sha256_file(path), sha256_file(tmp), members))
            print(f"  staged {current}: {len(members)} members verified")
    except Exception as exc:
        for tmp in temps:
            if os.path.exists(tmp):
                os.remove(tmp)
        print(f"🔴 {current}: {type(exc).__name__}: {exc}")
        print("   Nothing was replaced.")
        return 1

    for n, path, tmp, _, _, _ in staged:
        os.replace(tmp, path)

    today = datetime.date.today().isoformat()
    with open(manifest, "w", encoding="utf-8", newline="\n") as out:
        out.write("# REPACK-MANIFEST.txt\n")
        out.write(f"# Written by release-tooling/repack-tarballs.py on {today}.\n")
        out.write("# Each archive was re-packed to clear owner fields from its tar headers. For every member,\n")
        out.write("# the name, type, mode, mtime, size, link target and SHA-256 were asserted equal before and\n")
        out.write("# after. The archives as they were before re-packing are not in this bundle.\n")
        out.write("#\n")
        out.write("# archive <TAB> file <TAB> sha256-before <TAB> sha256-after <TAB> members\n")
        out.write("# member  <TAB> archive <TAB> type <TAB> sha256-before <TAB> sha256-after <TAB> name\n")
        for n, _, _, before_sha, after_sha, members in staged:
            out.write(f"archive\t{n}\t{before_sha}\t{after_sha}\t{len(members)}\n")
            for name, k, _mode, _mtime, _size, _link, digest in members:
                d = digest or "-"
                out.write(f"member\t{n}\t{k}\t{d}\t{d}\t{name}\n")
    print(f"  re-packed and replaced: {len(staged)} archive(s); manifest written")
    return 0


def check(archive_dir, manifest):
    archives, members = {}, {}
    with open(manifest, encoding="utf-8") as fh:
        for ln in fh:
            ln = ln.rstrip("\n")
            if not ln or ln.startswith("#"):
                continue
            cols = ln.split("\t")
            if cols[0] == "archive":
                archives[cols[1]] = (cols[3], int(cols[4]))
            elif cols[0] == "member":
                members.setdefault(cols[1], []).append((cols[5], cols[2], None if cols[4] == "-" else cols[4]))
    if not archives:
        print("🔴 the manifest names no archives")
        return 1
    bad = 0
    # The directory is the other half of this check. Iterating the manifest alone can only
    # report on files the manifest already knows about, so an archive that is present and
    # unnamed passes in silence - a clean verification of a file that was never read. Guard
    # the same case repack_all() guards from the other side, by listing what is actually there.
    on_disk = sorted(n for n in os.listdir(archive_dir) if n.endswith(".tar.gz"))
    for n in (n for n in on_disk if n not in archives):
        bad += 1
        print(f"  🔴 {n}: present in the directory but NOT NAMED in the manifest - not verified")
    for n, (after_sha, count) in archives.items():
        path = os.path.join(archive_dir, n)
        problems = []
        if not os.path.exists(path):
            problems.append("missing")
        else:
            if sha256_file(path) != after_sha:
                problems.append("whole-file SHA-256 differs")
            with tarfile.open(path, "r:gz") as tf:
                got = [(name, k, digest) for name, k, _m, _t, _s, _l, digest in describe(tf)]
                if not owners_neutral(tf):
                    problems.append("owner fields not neutral")
            if got != members.get(n, []) or len(got) != count:
                problems.append("members differ from the manifest")
        if problems:
            bad += 1
            print(f"  🔴 {n}: {'; '.join(problems)}")
        else:
            print(f"  ✅ {n}: {count} members match")
    print(f"  {len(archives)} archive(s) named in the manifest; "
          f"{len(on_disk)} *.tar.gz in the directory")
    return 1 if bad else 0


def main(argv):
    if len(argv) == 3 and argv[0] == "--check":
        return check(argv[1], argv[2])
    if len(argv) == 2:
        return repack_all(argv[0], argv[1])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
