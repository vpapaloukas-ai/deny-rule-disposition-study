#!/usr/bin/env python3
"""check-links.py - every relative Markdown link in the bundle must resolve inside the bundle.

  usage: check-links.py <bundle-dir>

Exit 0 = every relative link resolves. Exit 1 = at least one does not, or no link was checked.

WHY. The docs are written for the private layout, where the arms sit beside the record. In the
bundle they sit under results/, so the same links point at nothing in the published copy.
assemble-public-bundle.sh rewrites them; this checks the result.

Links inside fenced code blocks are not links and are skipped. External links (a scheme such
as https:) and in-page anchors are out of scope. A link that leaves the bundle root counts as
unresolved even if the target exists on this machine: a reader of the bundle will not have it.

Zero links checked is a failure, not a pass: it means this tool read nothing.
"""
import os
import re
import sys
from urllib.parse import unquote

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
FENCE = re.compile(r"^\s*(```|~~~)")
SKIP_DIRS = {".git"}


def links(path):
    in_fence = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for n, line in enumerate(fh, 1):
            if FENCE.match(line):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for m in LINK.finditer(line):
                yield n, m.group(1)


def main():
    root = os.path.realpath(sys.argv[1] if len(sys.argv) > 1 else ".")
    checked, broken = 0, []
    for dirpath, dirnames, names in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for name in sorted(names):
            if not name.endswith(".md"):
                continue
            src = os.path.join(dirpath, name)
            for line, target in links(src):
                if SCHEME.match(target) or target.startswith("#"):
                    continue
                checked += 1
                rel = unquote(target.split("#", 1)[0])
                dest = os.path.realpath(os.path.join(os.path.dirname(src), rel))
                inside = dest == root or dest.startswith(root + os.sep)
                if not (inside and os.path.exists(dest)):
                    broken.append((os.path.relpath(src, root), line, target))

    print(f"=== RELATIVE LINK CHECK - {root} ===")
    print(f"  relative links checked: {checked}")
    for src, line, target in broken:
        print(f"  🔴 {src}:{line} -> {target}")
    if checked == 0:
        print("  🔴 NO LINKS CHECKED - this tool read nothing, so a pass would be vacuous.")
        return 1
    if broken:
        print(f"  RESULT: 🔴 {len(broken)} unresolved.")
        return 1
    print("  RESULT: ✅ every relative link resolves inside the bundle.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
