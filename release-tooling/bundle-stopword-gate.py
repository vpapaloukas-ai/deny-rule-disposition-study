#!/usr/bin/env python3
"""bundle-stopword-gate.py - the release gate for public-release/.

WHY THIS EXISTS (findings 7.1 + 7.2, 2026-08-08):

  7.2  `textcheck.py` guards DRAFTS. The release bundle is not a draft, so no gate
       watched it, and a role label from the internal stop-keyword list reached three published
       documents 29 times. A protected internal record became a public artefact and
       the stop keyword rode along.

  7.1  The bundle's own scrub report NAMED THE STRINGS IT REMOVED - the employer
       name, the personal mail domain and the internal classification words all appeared
       in the documents certifying the bundle was clean. The content passed; the
       certificate leaked. So THIS TOOL REPORTS CATEGORIES AND COUNTS, NEVER THE
       MATCHED STRING OR THE PATTERN. Its own output is publishable.

Exit 0 = clean. Exit 1 = a category matched, an archive could not be read or held no files,
or the gate could not prove itself live.

  usage: bundle-stopword-gate.py <bundle-dir>

MAKING A NAMED PERSON VISIBLE ON PURPOSE (changed 2026-08-08 — read this before doing it):

  A third party may consent to being named. Citing published work by name is normal practice
  and an anonymised citation is less checkable than a named one, so this is a real request and
  not an edge case.

  The procedure is NOT "edit this file". Since the values moved out of here, the gate no longer
  contains the name to allow-list. Do it in two places instead:

    1. Remove that person's row from the external scrub-patterns file, so the assembler stops
       rewriting their name in the first place.
    2. Add them to IDENTIFIER_ALLOW below WITH A REASON, exactly as the already-public org and
       repo identifiers are handled. The reason is printed on every run.

  🔴 NEVER delete the category or stop scanning. An allow-list entry is a decision on the
  record, printed each time and re-readable by anyone. A deleted check is invisible the moment
  it is gone, and the next person cannot tell consent from an oversight.

  🔴 And consent covers a NAME, not a bundle. Re-run this gate after the change: removing a
  scrub row un-scrubs every occurrence of that string everywhere, including places that were
  never reviewed for it.
"""
import glob
import os
import re
import sys
import tarfile
import tempfile

# ---------------------------------------------------------------- categories
# (label, [regex]) - the label is what gets printed. The pattern never is.
CATEGORIES = [
    # 🔴 STRUCTURAL SHAPES ONLY — no personal string is written in this file. The specific
    # address, username and third-party name come from the external patterns file (see
    # load_personal_patterns). They used to be hardcoded here, which put the author's real
    # email into this very file as an escaped regex — where neither the scrub nor this gate
    # could see it, because an escaped domain is not the same string as the plain one.
    # Publishing the gate would have
    # published what the gate exists to remove.
    # The literal is split so this pattern does not match its own source line once the
    # escape-normaliser has run. The alternative — exempting this file from its own scan —
    # would be a hole big enough to hide anything in.
    ("personal email address",        [r"[\w.+-]+@" + "gmail" + r"\.com"]),
    # Deliberately NOT a generic `/home/<name>` pattern: the scrub REPLACES the real home
    # path with `/home/user`, so a generic pattern flags its own placeholder in 500+ files.
    # That is precisely the false positive the independent read produced (it reported ~878
    # "unscrubbed" paths that were all the placeholder). The real unix home path is caught
    # by the external personal-identifier category, which knows the actual username.
    # 🔴 BOTH SPELLINGS OF THE USER DIRECTORY, added 2026-08-11 after a real leak.
    # The drive-letter form alone was listed here. A path in the mount-prefix form, carrying
    # an account name and a temp-directory layout, sat in an allowlisted harness file and
    # this category — whose whole job is that directory — did not see it, because it was the
    # same directory written the other way. The repository category further down had listed
    # both of ITS forms since August; this one listed one.
    # Fourth instance of this study's own Arm D finding, now in its own release gate:
    # a literal-string matcher defeated by an alternative spelling of the same thing.
    #
    # 🔴 ALL FIVE SPELLINGS, 2026-09-17. "Both" was two of five: the drive form with forward
    # slashes, the same form JSON-escaped, and the Git Bash form were still unlisted, in this
    # category and in the repository one below. Each spelling is now a pattern here and a
    # rule in scrub-lib.sh, and the release-tooling tests plant one of each.
    #
    # 🪤 This comment names no path. The first version quoted both repository spellings to
    # make the point and the scrub rewrote them mid-build, which failed the byte-identity
    # guard. A comment that quotes what the scrub removes is rewritten by the scrub.
    # Describe the shape, never the string — especially when the string is the warning.
    # 🪤 The patterns are SPLIT for the same reason the repo-path and email patterns
    # below are split: written whole, the scrub rewrites the gate's own rule into
    # `<home>[A-Za-z]`, which matches nothing, and the published gate would pass a real leak
    # while looking identical. The build's byte-identity guard caught exactly that on the
    # first attempt. Concatenation is the established idiom here — keep it.
    ("local home path",               [r"[A-Za-z]:\\" + r"Users\\[A-Za-z]",
                                       r"[A-Za-z]:\\\\" + r"Users\\\\[A-Za-z]",
                                       r"[A-Za-z]:/" + r"Users/[A-Za-z]",
                                       r"/mnt/[a-z]/" + r"Users/[A-Za-z]",
                                       r"(?<![A-Za-z0-9._-])/[a-z]/" + r"Users/[A-Za-z]"]),
    # 🔴 SPLIT LITERAL, and it is load-bearing. This gate is COPIED INTO the bundle it
    # checks, so `assemble-public-bundle.sh` scrubs this file too — and the structural
    # repo-path rule rewrote this very pattern into the placeholder on 2026-08-08. The
    # published gate then hunted for the REPLACEMENT: it blocked a clean bundle, and it
    # would have passed one that genuinely leaked the path. Splitting the literal means the
    # scrub's regex finds no contiguous match in this source line, while Python still
    # compiles the whole string. Same trick as the email pattern above, same reason.
    # The last pattern is the project-directory slug Claude Code derives from the drive form.
    # This comment quotes NEITHER rule verbatim, on purpose — see the note at the bottom of
    # scan(). Naming a scrub rule inside a scrubbed file rewrites the explanation too.
    ("local repository path",         [r"/mnt/[a-z]/" + r"web/",
                                       r"[A-Za-z]:\\" + r"web\\",
                                       r"[A-Za-z]:\\\\" + r"web\\\\",
                                       r"[A-Za-z]:/" + r"web/",
                                       r"(?<![A-Za-z0-9._-])/[a-z]/" + r"web/",
                                       r"(?<![A-Za-z0-9])[A-Za-z]--" + r"web-"]),
    # 🔴 Added 2026-09-17. A path scrubbed ONE SEGMENT SHORT carries no drive, mount or web
    # root any more, so every pattern above passes it - and it still names the internal
    # layout between the placeholder and the experiments directory. The tree moved one
    # segment deeper on 2026-08-23, and a worktree adds two more, so a fixed-depth scrub
    # produces exactly this. The placeholder followed directly by the experiments
    # directory is the correct form and does not match.
    ("local repository path, scrubbed one segment short",
                                      [r"<repo>[\\/]+(?:[A-Za-z0-9._-]+[\\/]+)+experiments\b"]),
    ("session identifiers",           [r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"]),
    # NOTE: "walled" / "the wall" is deliberately NOT in this pattern. In this study it
    # names the oracle-isolation design — a root-owned log directory the agent user cannot
    # read — which is legitimate, publishable methodology. It sat here until 2026-08-08 and
    # produced 5 hits, every one of them that concept. The internal document-classification
    # scheme is the actual risk, and it returns zero. A gate that cries wolf gets ignored,
    # and then it is not a gate.
    ("internal classification vocabulary", [r"\bTIER ?[12]\b", r"\bT[12] only\b",
                                            r"\bproprietary\b", r"\bdisclosure tier\b"]),
    # Split for the same reason: the role-label generalisation is one of the structural scrub
    # rules, so the unsplit form of this pattern was rewritten in the published copy.
    ("positioning / status stop-keyword",  [r"\bfound" + r"er\b", r"\bstealth\b", r"\bpre-launch\b"]),
    ("credential material",           [r"api[_-]?key\s*[:=]", r"BEGIN [A-Z ]*PRIVATE KEY", r"\bsecret\s*[:=]"]),
    # Added 2026-08-08 after the independent read. The gate had NO category for third
    # parties: it was built entirely from "what identifies the author", so it could not
    # see the one person in the bundle who never agreed to be in it. A named practitioner
    # appeared across 5 files while the author's own username was scrubbed. Whoever writes
    # the pattern list writes their own blind spots into it — which is the whole reason the
    # release requires a read by something that did not author the scrub.
    #
    # 🔴 "third-party personal name" IS DELIBERATELY NOT LISTED HERE. It held the real name
    # as a literal until 2026-08-08, which meant the scrub rewrote it to the replacement
    # string inside this file, and the published gate then searched for "another
    # practitioner" instead of for the name. It failed on a clean bundle and would have
    # passed a genuine leak. The name now comes from the external patterns file, so this
    # file states the REQUIREMENT and never the VALUE — see REQUIRED_EXTERNAL_CATEGORIES.
]

# 🔴 Added 2026-09-17. Tar headers carry the packing account's user and group, as names and as
# numeric ids, and the scrub never touches them: it rewrites file CONTENTS. So an archive whose
# every file scrubbed clean could still name the account that packed it. This category reads the
# headers, not the files, and passes only an empty or root owner with numeric id 0. It checks
# a shape, never an instance: no account name is written here.
ARCHIVE_OWNER_CATEGORY = "archive owner metadata"

# Categories whose patterns are supplied from outside the repo. Naming them here is what
# makes an UNARMED scan visible: without this list a missing external file would simply
# produce no category and no row, and the gate would print a confident clean result for a
# check that never ran. Declared requirement, external value.
REQUIRED_EXTERNAL_CATEGORIES = ["third-party personal name"]

DEFAULT_EXTERNAL_CATEGORY = "personal identifier (external list)"
# These match case-insensitively. "local unix username" does NOT: the lowercase unix
# name is the leak, while capitalised "Vagelis Papaloukas" is the public brand and is
# kept on purpose. A case-insensitive check here conflates them and buries a real leak
# in known-benign noise (measured 2026-08-08: it scored the brand as 8 sensitive hits).
CASE_SENSITIVE = {"personal identifier (external list)"}

# Loaded from outside the repo; these are the real employer/client/project names.
# The list lives OUTSIDE the repo, so a clone or another machine will not have it — and the
# gate must fail loudly rather than report a vacuous clean. Under WSL, `~` is the Linux home
# while the file sits on the Windows side, which silently disabled this whole scan on its
# first run through the build script; the /mnt/c candidates fix that.
IDENTIFIERS_PATHS = [
    os.environ.get("TEXTCHECK_IDENTIFIERS", ""),
    os.path.expanduser("~/.claude/textcheck-identifiers.txt"),
] + sorted(glob.glob("/mnt/c/Users/*/.claude/textcheck-identifiers.txt"))

# Positive control: a string that MUST be found, proving the scanner actually read the
# tree. Without it a "0 hits" result is indistinguishable from a scanner that opened
# nothing - which is exactly how this bundle once certified itself clean while holding
# no files at all.
CONTROL = ("public brand (positive control)", r"Vagelis Papaloukas")


# Identifiers that are DELIBERATELY public in this bundle's context. The identifier list
# is calibrated for DRAFTS, where naming the showcase org is a positioning leak. This
# bundle is a different artefact: the template under test is public, and the study is
# unreadable without naming it. Allow-listing is explicit, reasoned and printed — a
# silent suppression is how a gate rots into decoration.
# Every entry here must be independently verifiable as already public.
IDENTIFIER_ALLOW = {
    "agent-team-starter": "the repo that IS the system under test; public at github.com/vpapaloukas-ai/agent-team-starter",
    "vpapaloukas-ai":     "the public GitHub org that hosts it",
    "vpapaloukas":        "public brand/domain, kept for attribution; the private form (personal email) is caught by the 'personal email address' category",
}


def load_personal_patterns():
    """Personal strings (address, username, third-party name) read from OUTSIDE the repo,
    so that publishing this gate does not publish the values it removes.

    Returns {category_label: [pattern, ...]}.

    File format, tab-separated:   pattern <TAB> replacement [<TAB> category]

    The third column is optional and new in 2026-08-08. Rows without it fall into
    DEFAULT_EXTERNAL_CATEGORY, so an older two-column file keeps working unchanged — the
    scrub reads the same file and must not be disturbed by a gate-side change.
    """
    cands = [os.environ.get("SCRUB_PATTERNS", ""),
             os.path.expanduser("~/.claude/scrub-patterns.txt")]
    cands += sorted(glob.glob("/mnt/c/Users/*/.claude/scrub-patterns.txt"))
    for c in cands:
        if c and os.path.exists(c):
            out = {}
            for ln in open(c, encoding="utf-8"):
                ln = ln.rstrip("\n")
                if not ln.strip() or ln.lstrip().startswith("#"):
                    continue
                cols = ln.split("\t")
                pat = cols[0].strip()
                cat = cols[2].strip() if len(cols) > 2 and cols[2].strip() else DEFAULT_EXTERNAL_CATEGORY
                if len(pat) >= 3:
                    out.setdefault(cat, []).append(pat)
            return out
    return {}


def load_identifiers():
    for p in IDENTIFIERS_PATHS:
        if p and os.path.exists(p):
            vals = [ln.strip() for ln in open(p, encoding="utf-8")
                    if ln.strip() and not ln.startswith("#")]
            kept, allowed = [], []
            for v in vals:
                if len(v) < 3:
                    continue
                (allowed if v.lower() in IDENTIFIER_ALLOW else kept).append(v)
            return kept, p, allowed
    return None, None, []


# Git's own object store and metadata, which a CLONE carries but a bundle does not.
# Found 2026-08-10 by cloning the published repo and running this gate on it the way a
# reader is told to: it returned BLOCKED on a clean bundle. The hits were the commit
# author line - an email that is attribution, present in every commit anyone ever makes,
# and already public on the author's other repos - not anything in the study.
#
# A check that cries wolf on clean work is this study's own subject matter turned on its
# own tooling, and the first outsider to run it is the practitioner who asked for the
# method. So `.git` is excluded: it is not part of the published artefact.
#
# 🔴 The bound on that reasoning, rewritten 2026-09-17 because its premise stopped being true.
# It used to say the exclusion was safe because the repository was a single flat commit, so
# the objects were exactly the tree. The repository this gate now certifies has history from
# its first commit, the re-run's pre-registration. This gate therefore certifies a TREE, not a
# history: a secret can survive in an earlier commit or an unreachable object while the tree it
# scans is clean, and nothing in this file looks there. It says so in its own output too.
SKIP_DIRS = {".git"}


def iter_text_files(root):
    for dirpath, dirnames, names in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for n in names:
            fp = os.path.join(dirpath, n)
            if n.endswith((".tar.gz", ".tgz", ".zip", ".pdf", ".png", ".jpg")):
                continue
            try:
                with open(fp, encoding="utf-8", errors="replace") as fh:
                    yield os.path.relpath(fp, root), fh.read()
            except OSError:
                continue


def _owner_clean(member):
    return (member.uid == 0 and member.gid == 0
            and member.uname in ("", "root") and member.gname in ("", "root"))


def _extract(tf, dest):
    # The "data" filter refuses members that would land outside dest. Where it exists, use it;
    # a member it refuses raises, and a raise below means the archive is reported, not skipped.
    if hasattr(tarfile, "data_filter"):
        tf.extractall(dest, filter="data")
    else:
        tf.extractall(dest)


def iter_tarball_files(root, archives):
    # 🔴 EVERY ARCHIVE IS ACCOUNTED FOR, 2026-09-17. An archive that failed to open used to be
    # skipped with a bare `continue`: a truncated or corrupt tarball contributed zero files and
    # the gate still reported clean. The positive control could not see it, because the control
    # fires if ANY file in the bundle carries the brand, and the README alone does. So `archives`
    # records, per archive, either the error type or its file count and owner count, and main()
    # blocks on an archive that could not be read or held no files.
    for dirpath, dirnames, names in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]  # same exclusion, same reason
        for n in names:
            if not n.endswith((".tar.gz", ".tgz")):
                continue
            fp = os.path.join(dirpath, n)
            rel = os.path.relpath(fp, root)
            with tempfile.TemporaryDirectory() as td:
                try:
                    with tarfile.open(fp) as tf:
                        members = tf.getmembers()
                        _extract(tf, td)
                except Exception as exc:
                    archives[rel] = {"error": type(exc).__name__}
                    continue
                archives[rel] = {
                    "files": sum(1 for m in members if m.isfile()),
                    "owned": sum(1 for m in members if not _owner_clean(m)),
                }
                # 🔴 MEMBER NAMES, added 2026-09-17. The scrub rewrites what files contain, never
                # what they are called, and this gate used to read only contents: a directory or
                # file named with a session identifier or a home path would have shipped past both.
                # Every member name, directories included, is scanned as one more body. The
                # existing archives measured clean on that day; the check is for the next ones.
                yield f"{rel}::(member names)", "\n".join(m.name for m in members)
                for sub, body in iter_text_files(td):
                    yield f"{rel}::{sub}", body


def scan(root):
    ids, _ids_path, allowed = load_identifiers()
    cats = list(CATEGORIES)
    pers = load_personal_patterns()
    for label in sorted(pers):
        if label == DEFAULT_EXTERNAL_CATEGORY:
            # Legacy behaviour, unchanged: raw substring, case-sensitive (see CASE_SENSITIVE).
            cats.append((label, pers[label]))
        else:
            # 🔴 Word-boundaried, and this is not decoration. A personal name is a word.
            # Taken raw, the name pattern matched a random alphanumeric token inside one
            # transcript and the gate reported a leak that was not there. The hardcoded
            # pattern this replaced carried word boundaries; moving the value outside the
            # repo must not quietly drop them.
            # Case-insensitive is kept deliberately and is STRONGER than the scrub: `sed` is
            # case-sensitive, so a name written in prose with different casing is a real leak
            # the scrub would miss and this catches.
            #
            # 🪤 And note this comment quotes neither the name nor the matched token. The
            # header above records three earlier comments that reintroduced the very value
            # they were explaining. The first draft of THIS comment was the fourth: it
            # spelled out the old hardcoded pattern, so the scrub rewrote the explanation
            # and republished the name in the same stroke. Describe the shape, never the
            # string — including when the string is the thing you are warning about.
            cats.append((label, [r"\b" + p + r"\b" for p in pers[label]]))
    if ids:
        cats.append(("employer / client / project identifiers",
                     [r"\b" + re.escape(v) + r"\b" for v in ids]))

    compiled = []
    for label, pats in cats:
        flags = 0 if label in CASE_SENSITIVE else re.IGNORECASE
        compiled.append((label, [re.compile(p, flags) for p in pats]))
    _, ctrl_pat = CONTROL
    ctrl_rx = re.compile(ctrl_pat)

    # 🔴 Scan the text BOTH as-is and with regex/shell escaping stripped. A personal string
    # written as a PATTERN — dots escaped, as any removal rule must write them — is invisible
    # to a matcher looking for the plain form, because the escaped and plain spellings are
    # different strings. That is how the release tooling carried the author's real address
    # past this gate on 2026-08-08: the escaping needed to write the removal rule hid the
    # thing being removed. Normalising closes the general case, not just that instance.
    #
    # (And note this comment names no address. Three separate comments explaining this defect
    #  reintroduced it by quoting the value they were describing.)
    def unescape(t):
        return re.sub(r"\\([.\-+*?()\[\]{}|^$@/])", r"\1", t)

    hits, ctrl_hits, scanned, archives = {}, 0, 0, {}
    for source in (iter_text_files, lambda r: iter_tarball_files(r, archives)):
        for relpath, raw in source(root):
            # The path is scanned with the contents: a file's name is published too.
            body = relpath + "\n" + raw + "\n" + unescape(raw)
            scanned += 1
            if ctrl_rx.search(body):
                ctrl_hits += 1
            for label, rxs in compiled:
                if any(rx.search(body) for rx in rxs):
                    hits.setdefault(label, set()).add(relpath)
    for rel, info in archives.items():
        if info.get("owned"):
            hits.setdefault(ARCHIVE_OWNER_CATEGORY, set()).add(rel)
    return hits, ctrl_hits, scanned, ids, allowed, pers, archives


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    hits, ctrl_hits, scanned, ids, allowed, pers, archives = scan(root)

    print(f"=== RELEASE STOP-KEYWORD GATE - {root} ===")
    print(f"  files scanned (incl. tarball contents): {scanned}")

    fail = False

    if ids is None:
        print("  🔴 IDENTIFIER LIST NOT FOUND - the employer/client/project scan DID NOT RUN.")
        print("     A clean result here would be vacuous. Set TEXTCHECK_IDENTIFIERS or create")
        print("     ~/.claude/textcheck-identifiers.txt, then re-run.")
        fail = True
    else:
        print(f"  identifier list loaded: {len(ids)} entries scanned (from outside the repo)")
        if allowed:
            print(f"  {len(allowed)} identifier(s) ALLOW-LISTED as already public:")
            for a in allowed:
                print(f"       - {IDENTIFIER_ALLOW[a.lower()]}")

    # Every category whose patterns live outside the repo must be proved ARMED. An external
    # category that loaded nothing produces no row at all, so without this check the report
    # would omit it silently and still print a clean result - the same vacuous pass the
    # identifier check above already refuses. Declared in REQUIRED_EXTERNAL_CATEGORIES so the
    # requirement is auditable in the published source while the values stay out of it.
    unarmed = [c for c in REQUIRED_EXTERNAL_CATEGORIES if not pers.get(c)]
    if unarmed:
        print("  🔴 EXTERNAL CATEGORY NOT ARMED - these scans DID NOT RUN:")
        for c in unarmed:
            print(f"       - {c}")
        print("     Their patterns come from the scrub-patterns file (tab-separated:")
        print("     pattern <TAB> replacement <TAB> category). Without it a 0 below is not a")
        print("     pass, it is a scan that never happened.")
        fail = True
    else:
        armed = ", ".join(REQUIRED_EXTERNAL_CATEGORIES)
        print(f"  ✅ external categories armed from outside the repo: {armed}")

    if ctrl_hits == 0:
        print("  🔴 POSITIVE CONTROL DID NOT FIRE - the scanner found nothing at all, which")
        print("     means it is not reading the tree. Treat every 0 below as meaningless.")
        fail = True
    else:
        print(f"  ✅ positive control fired in {ctrl_hits} file(s) - the scanner is live")

    # Per-archive accounting. A count printed for every archive is the control for each one:
    # a reader can see that each was opened and what it held, not only that the tree as a
    # whole produced a hit somewhere.
    print(f"\n  archives read: {len(archives)}")
    for rel in sorted(archives):
        info = archives[rel]
        if "error" in info:
            print(f"  🔴 {rel}: COULD NOT BE READ ({info['error']}) - its contents were NOT scanned")
            fail = True
        elif info["files"] == 0:
            print(f"  🔴 {rel}: HOLDS NO FILES - nothing in it was scanned")
            fail = True
        else:
            print(f"     {rel}: {info['files']} files")

    print("\n  category                                    files")
    print("  " + "-" * 58)
    extra = ([(lbl, None) for lbl in sorted(pers)]
             + ([("employer / client / project identifiers", None)] if ids else [])
             + [(ARCHIVE_OWNER_CATEGORY, None)])
    for label, _ in CATEGORIES + extra:
        n = len(hits.get(label, ()))
        mark = "🔴" if n else "  "
        print(f"  {mark} {label:<42} {n}")
        if n:
            fail = True
            for f in sorted(hits[label])[:10]:
                print(f"       - {f}")

    print()
    print("  ── WHAT THIS GATE CANNOT SEE ──────────────────────────────────────────")
    print("  It matches STRINGS. It cannot detect a disclosure that is a correctly-")
    print("  spelled, accurate, unremarkable sentence - an operator's account setup,")
    print("  security posture, machine layout, or working habits described in prose.")
    print("  One such file existed here and scored clean on every category above.")
    print("  It does not read git history: `.git` is skipped, so an earlier commit can")
    print("  hold what the scanned tree does not.")
    print("  A clean result below therefore means NO KNOWN PATTERN MATCHED. It does")
    print("  not mean the bundle is safe to publish. Two things establish that, and")
    print("  neither is automatable:")
    print("     1. the file allowlist  (release-tooling/RELEASE-ALLOWLIST.txt) - default deny")
    print("     2. a read by someone/something that did not author the scrub")
    print()
    if fail:
        print("  RESULT: 🔴 BLOCKED. Do not publish.")
        print("  (Categories only by design - this report is itself publishable.)")
        return 1
    print("  RESULT: ✅ No pattern matched. NECESSARY, NOT SUFFICIENT - see above.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
