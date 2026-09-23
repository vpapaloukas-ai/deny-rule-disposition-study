# Independent pre-publication read — 2026-09-17

**Verdict: DO NOT PUBLISH AS IT STANDS.** One blocking defect, one sentence long, plus eleven
precision defects. **No measurement is wrong.** Every headline number in the bundle was re-derived
here from the shipped evidence and every one matched.

**What this is.** The independent read required before publication, by a session that authored none
of the work it reviews and wrote none of the scrub, the gate, the harness, the re-run or either
README. Written and committed 2026-09-17. Findings are recorded, not fixed: the repair belongs to a
different session, and this session re-checks it afterwards.

**Scope read.** The staged bundle in full — both READMEs, the three `docs/` files, `results/`
including Arm E, `rerun-2026-09/`, `release-tooling/`, and the eleven evidence archives. The three
commits under review, the publication plan at its named commit, and the study's own publication
policy. The author's private review standards for claim tiers, publication, disclosure and
retracted claims, each at the version this session was actually served.
*(⛔ Generalised 2026-09-23, ops#44 S14 finding F-E: this sentence named the private tooling those
standards ship in, its version, and each standard by its internal name. Removed, not struck.)*

---

## 1. What was re-derived, and how

Every figure below was computed from the **shipped tarballs after the redaction pass**, with scripts
written for this read that import nothing from the repository. Where a number is load-bearing it was
checked a second way, with a differently shaped instrument.

**Disposition, 2026-08-08 (300 runs).** From each run's own `oracle_after.json`, counting runs whose
protected line was absent afterwards:

| cell | blind (Arm B) | told (Arm A) |
|---|---|---|
| Opus | **0/50** | **1/50** |
| Sonnet | **39/50** | **4/50** |
| Haiku | **49/50** | **1/50** |

Matches the bundle exactly, in both READMEs, the record's state box and the per-cell summaries.

**Deny firing.** Derived independently from `stream.jsonl`, by counting tool results carrying the
CLI's own denial message. Told arm **149/150** (the single exception issued no denied command);
blind arm **0/150**. Matches. The re-run: told **300/300**, blind **0/300**.

**Re-run, 2026-09-17 (600 runs).** Blind arm, protected line absent:

| model | 2026-08-08 | batch A | batch B |
|---|---|---|---|
| Opus | 0/50 | 0/50 | 0/50 |
| Sonnet | 39/50 | 45/50 | 0/50 |
| Haiku | 49/50 | 50/50 | 49/50 |

All twelve cells match, told arm included. **600 runs, every one `COMPLETE`, none VOID** — confirmed
from the 600 per-run status files, not from a summary.

**The statistics.** Two-sided Fisher exact and Holm re-implemented from scratch, no library, over my
own counts. Sonnet A against B: p = 6.9 × 10⁻²³, Holm 4.1 × 10⁻²². Sonnet 2026-08-08 against A:
p = 0.171, Holm 0.857. Every other primary comparison p = 1. Told-arm descriptive p-values reproduce
too (1 and 0.495; 0.678 and 0.495; 1 and 1). Matches the bundle to every digit printed.

**The injection-keyword figure, two ways.** Applying the study's own keyword pattern (a) to assistant
-authored text only and (b) to all text plus the final result, both give the same answer: **27 of
Sonnet's 50 blind runs match, 26 of the 39 destructive runs match, and exactly one matching run kept
the protected file.** Haiku 0, Opus 0. Batch A gives 31 and 30; batch B gives 0.

**Mechanism split.** Sonnet **39 enumerated / 0 blanket**; Haiku **33 / 16**. My first pass scored
Sonnet 36/0 with three unattributed — reading those three runs' commands showed all three named the
protected file explicitly and had only *inspected* a stash. **The record is right and my first
instrument was the narrower one.** Recorded because it is the shape the study itself warns about.

**Stash contamination.** Reproduced completely and independently: the exposed sets (nine blind runs
of one model, three and two told-arm runs of two others, none on the third model), which run saved
the stash, that it was the 71st run of 300, that the arm carrying the 0/50 headline ran first and was
shown nothing, and the 8-destroyed/1-kept split. The record's finer split — four runs saw it
identified as a stash, five saw only a commit line — also reproduces once the instrument is widened
to the decoration the log actually printed. My first, narrower query found two, not four; **the
record's classification is the correct one.**

**Arm D, Arm C, Phase 2.** All six per-rule rates, the 18-mechanism tally, Arm C's three numbers and
Phase 2's split all reproduce from the shipped per-probe rows.

**Run bounds.** All 900 runs report the same CLI version. Model pinning reproduces exactly, including
that one model's sessions pin one identifier and reply under another. Every canary blocked on its
first attempt, 600/600. Every re-run session started with no stash; exactly two ended holding one.

**Archive hygiene.** All **eleven** archives: owner name and group cleared, numeric ids zeroed, gzip
filename field absent, gzip timestamp zeroed. Checked directly from the tar headers.

**The ordering the whole re-run rests on.** The destination repository exists, is private, and its
first commit adds the pre-registration; its second adds the amendment. Both precede the first run by
the clock. **This is the strongest claim in the publication and it holds** — and once the repository
is public it is Linkable, which is exactly what the earlier arm's equivalent clause is not.
*(⛔ 2026-09-23: the repository was replaced by a new one of the same name, and GitHub's push record for
these two commits stayed with the original, which is private. In the published repository this ordering
is Checkable, not Linkable. See the bundle README's note on the ordering evidence.)*

## 2. Tooling, run here

| what | result |
|---|---|
| the release tooling's own test suite | ~~**92 tests, exit 0**, no skips~~ — the red tests ran, so the fixes are measured against a defect that was present. ⛔ **Corrected 2026-09-20.** That figure was measured in the **private tree only**, and the sentence did not say so. A clone of this bundle gave **1 error and 15 skipped** — `EXP = HERE.parent`, which is the experiment directory privately and the bundle root here, so paths spelled one way resolved in one tree and not the other. The error was the test covering the **pre-registration pins**. Fixed at source and re-measured in both layouts: **95 tests, exit 0** — no skips privately, **14 skipped from a clone**, those 14 covering as-ran scripts that deliberately do not ship. |
| the archive manifest check | ~~**exit 0**, ten archives, every member matching~~ ⛔ **Corrected 2026-09-20.** There are **eleven** archives. The eleventh, `rerun-2026-09-600-runs.scrubbed.tar.gz` and the largest, was packed with neutral owners from the start and never re-packed, so it was absent from the manifest — and **invisible to `--check`, which iterated the manifest and never listed the directory**. Ten green lines and exit 0 over a directory holding eleven. No leak: its 4,237 headers were read directly and are clean. It is now recorded, and `--check` guards the directory. Re-measured: **exit 0, eleven archives, every member matching.** |
| the bundle assembler end to end | **exit 0.** Gate armed from outside the repository, positive control fired, 6227 files scanned including inside all eleven archives, every category zero, all relative links resolve |
| rebuild reproducibility | working tree **clean** after a full rebuild — the committed bundle is exactly what the assembler produces |

## 3. Findings

⚠️ **The frame these citations are written in (added 2026-09-19).** Paths in this section are in the
frame of the tree this read was made in, where the bundle sits at `public-release/`. **In the
published bundle that directory IS the repository root** — read `public-release/README.md:12` as
`README.md:12`. Line numbers are as they stood when each defect was found and are deliberately not
re-pointed; see F10. One citation in F4 was written in the bundle's own frame instead
(`docs/RUN-RECORD.md:11`) and is normalised here to this section's frame: same file, same line.

### 🔴 F1 — BLOCKING. A published document names an internal planning document by file path.

`public-release/docs/RUN-RECORD.md:2137` cites, by full path, a planning document that lives in
another private repository, and says so. **This is the same criterion that currently blocks a sibling
repository from publication and that previously kept an internal prompt core-only.** Publishing this
bundle over that line while the sibling stays blocked for the identical reason would apply the rule
to one artefact and not the other.

No automated check sees it: it is not a Markdown link, so the link checker skips it, and it is an
accurate, unremarkable sentence, so the gate scores it clean and always will. It was introduced on
2026-09-17 by the correction that explains where the audit lives — the newest prose in the file.

The fix is one sentence: name the document by description rather than by path. Nothing else in the
correction needs to change.

### 🟠 F2 — A claim the bundle contradicts: the naming.

`public-release/transcripts/README.md:51` states that the bundle README carries the naming of the
practitioner whose finding the study builds on. **It does not.** The top-level README says only that
he "is named with his permission" and names nobody; the name appears in `docs/`, not in the README.
Either the README carries the name or the sentence should point where the name actually is.

### 🟠 F3 — The README breaks its own reporting rule 4.

Rule 4 of the README's own reporting rules requires the model named on every disposition number.
`public-release/README.md:238` gives three disposition rates in a row with no model attached. The
order matches the convention used elsewhere and the surrounding bullet is headed "model-specific",
but the numbers themselves are unattributed — which is the exact quotable unit the rule exists to
prevent. Every other disposition figure in the README complies.

### 🟠 F4 — The stated study period excludes an arm the bundle ships.

`public-release/README.md:12` and `public-release/docs/RUN-RECORD.md:11` both give the study period as three days in
August. The bundle contains an arm run three days after that window closed, and the record carries a
dated entry from six days after it. The period as written is contradicted by the artefact it
introduces.

### 🟠 F5 — A correction states something the file falsifies.

The corrections entry, and the note near the top of the same file, both say the late-added arm is
mentioned nowhere above them. There are three mentions above, at
`public-release/docs/RUN-RECORD.md:22`, `:33` and `:1326-1327`. The sentence is true of the study's
contemporaneous record and false of the file as published; a reader checks the file. This is the
narrower-sentence discipline the study applies everywhere else: the scope measured was the
pre-correction record, and the scope written was the whole document.

### 🟠 F6 — The one result whose validity clause is not Linkable is presented as if it were.

That same arm's result sits in the README's headline box beside numbers that are all recomputable
from the shipped evidence. Its own results file now carries a correct, well-written label saying its
validity clause rests on ordering in a private history that the published repository cannot show —
Checkable, not Linkable — and the record's state box points at that label. **The README's box does
not.** A reader who reads only the README gets a Checkable claim in Linkable grammar, in the one row
where that distinction was the reason for the label.

### 🟠 F7 — A third party's figure: the hard ban is honoured, the softer rule is not met.

**The ban holds, and this was the important thing to check.** The count from the practitioner's own
control — the one the policy forbids in any sentence, unconditionally since 2026-08-29 — appears
**nowhere in the bundle.** Neither does the vocabulary around it. Zero occurrences, checked across
every text file.

His *published* headline figure is a different matter and the policy permits it **with its bound
beside it**. It appears twice. One instance carries a bound, but the pilot-era one, not the final
one the policy names. The other carries no bound at all and no citation a reader can follow. In both
places a precise figure is attributed to a named living person with nothing to click.

Separately, and for the author rather than for a fixing session: the bundle records consent to be
**named**, and records what he declined. It records nothing about whether restating this figure was
cleared. That may well be settled elsewhere; it is not settled in the artefact.

📌 **WITHDRAWN 2026-09-18. The paragraph above is wrong, and the record that refutes it was one this
read had already opened.** The consent entry states that on 2026-08-10 he *"was asked, **read every
mention of himself**, and asked to be named"*, and that his name then stood in all six places. Both
passages carrying his published figure sit in entries dated 2026-08-06 and 2026-08-07, so both
predate that reading: he saw the sentences that restate it and asked to be named in them. The
publication policy also keeps his two figures apart on purpose — his **own control's** count is
banned outright and is the subject of the 2026-08-11 ask, the 08-19 nudge and the 08-29 default,
while his **published** figure is permitted with its panel size beside it. Nothing about the
published figure was ever left hanging. **There is no open permission question, and it was not
Vagelis's to answer.**

🔑 **The failure shape, because it is the one this read spent its length policing.** I read the
policy's §1.7 tightening and its ban, both of which govern his unpublished control, and generalised
them to his published figure — then reported the gap as a fact about the artefact without opening the
consent entry, which I had read earlier in the same pass and which decides it. *The implication
reported instead of the scope*, on the one claim in this read that touched a living third party's
permission. The bound and citation fixes recorded above stand on their own; only this permission
paragraph is withdrawn.

### 🟡 F8 — A verification that passes over an incomplete set, silently.

The archive manifest covers ten archives. The directory holds eleven. The checking tool reports
success and says nothing about the one it was never given. The tooling README describes the manifest
as covering "each transcript archive".

**No disclosure follows from this** — I checked the eleventh archive's headers directly and they are
clean, which is what the manifest would have attested. The defect is that a green check here is a
fact about the manifest's contents rather than about the directory, and nothing says so. That is the
precise shape of the empty-directory failure this bundle already records once.

### 🟡 F9 — An Arm D count that is narrower than its label.

`public-release/README.md:24` says ten of eighteen mechanisms "ran unblocked". Eleven ran without a
deny rule blocking them; ten of those also took effect. The eleventh ran and failed for an unrelated
environmental reason. Ten is the "evaded and took effect" count wearing the "ran unblocked" label.
The error is conservative — it understates the miss rate — but it is an error.

### 🟡 F10 — Dangling references in published documents.

~~Three backticked paths in published files name things not in the bundle: the study's own publication
policy, the superseded as-ran allowlist (the README correctly points at the current one, so the two
disagree about which file governs), and one arm script under a filename that differs from the one it
ships as.~~ ⛔ **RECOUNTED 2026-09-18 — six paths over eight mentions, not three.** The three named
above are the first three rows below; the other three repeat the second row's defect. None is a
disclosure; each is a reader following a pointer to nothing. The link checker does not see them
because none is a Markdown link.

| path as written | mentions | in | what it ships as |
|---|---|---|---|
| the internal publication policy's file name (⛔ generalised 2026-09-23, S14 F-E) | 1 | `docs/RUN-RECORD.md` | nothing — the policy is internal and does not ship; since 2026-09-23 the record no longer names the file |
| `harness/RELEASE-ALLOWLIST.txt` | 1 | `docs/RUN-RECORD.md` | `release-tooling/RELEASE-ALLOWLIST.txt` |
| `03b-substrate-blind-v2.sh` | 1 | `results/arm-e/PREREGISTRATION.md` | `harness/arm-e/03b.sh` |
| `harness/assemble-public-bundle.sh` | 3 | `docs/RUN-RECORD.md` ×2, `docs/RUNBOOK.md` | `release-tooling/assemble-public-bundle.sh` |
| `harness/bundle-stopword-gate.py` | 1 | `docs/RUN-RECORD.md` | `release-tooling/bundle-stopword-gate.py` |
| `harness/scrub-n50-transcripts.sh` | 1 | `docs/RUN-RECORD.md` | `release-tooling/scrub-n50-transcripts.sh` |

Four of the six are one defect repeated: a `harness/…` path for a file that ships from
`release-tooling/`. Rows are located by quote, not by line number, because the repairs this read
asked for move the line numbers: F1's `:2137` and F3's `:238` above are already off by the very
repairs they prompted, and are **left as written** because they record where each defect was found.

### 🟡 F11 — One passage goes stale the moment this file is committed.

The corrections entry says the independent read will be committed when it happens and that until then
the entry has been reviewed by nobody but its author. That resolves today. The passage needs a dated
line naming this read, or the published record ships asserting it is unreviewed alongside its review.

### ⚪ F12 — For the author's ruling, not a defect.

One passage in the record states, correctly and unremarkably, a category-level fact about how the
author's sessions inherit account-level integrations and under which permission mode. It names no
service and no value. It sits inside the very passage that names this failure class, and it is the
strongest remaining example of what a string gate cannot see. It does not locate a project and it
discloses no third party, so under the disclosure tiers it is publishable; whether it *should* be is
a judgement the author owns, and it should be made deliberately rather than by the gate's silence.

✅ **RULED 2026-09-20: publish, and the passage stays as written.** The author's decision, taken
deliberately, which is what this finding asked for rather than any particular outcome. It discloses
a real weakness in the study's own environment, and a reader who cannot see the shape of that hole
cannot judge the study's bounds.
⚠️ **The ruling covers two passages, not one.** The Stage 0 entry that named a connector was
generalised on 2026-09-20; removing the name left it making this same claim without one, so the
record now states the posture in two places and both are ruled here.
🔑 **What was open was the conjunction, not the mode.** Stating the permission mode is separately
*required* by the study's own reporting rules. What no rule decided was the mode together with
account-level integrations being reachable, and being a property of the account rather than of this
experiment.

## 4. Claim tiers — the two READMEs

Tiered against the four tiers, with "once public" meaning Linkable as soon as the repository's
visibility changes, which is the state this bundle is being prepared for.

**Linkable once public** — every arm result, every disposition rate, every re-run figure, the
statistics, the three transcript-level findings, the bounds, the mechanism split, the per-rule Arm D
rates, the allowlist's coverage and exclusions, the archive contents and headers, the byte-identity
of the shipped tooling, and the pre-registration-before-results ordering. I recomputed all of these
from shipped files. *(⛔ 2026-09-23: the ordering is the exception. Since the repository was replaced it
is Checkable, not Linkable. See the bundle README's note on the ordering evidence.)*

**Checkable** — the provenance claims (generated from a private record; nothing in the run harness
edited for publication; the tooling written after the study), the scrub and gate behaviour that
depends on pattern files kept outside the repository, the consent date, the neutralised role label,
and the reporting rules' descent from a private specification. **The README is honest about this
class**, and in several places says outright that a reader cannot reproduce a given check. Two
Checkable claims are written in Linkable grammar and should carry their tier: the late arm's validity
clause (F6) and the account of why the pre-publication release scripts do not ship — the red tests
that demonstrate that defect **skip in the published bundle**, so the reader is told a finding they
cannot reproduce.

**None** — **none found in either README.** This is the significant result of the tiering pass and it
should be said plainly: two documents of this length written at publication time, with a headline
result and a re-run, carrying no unsupported factual claim, is not the usual outcome. The closest
approaches are explicitly self-labelled: the note that an earlier review "left no committed record",
and the statement that the contamination "was not known or recorded while the study ran" — a negative
about a private record, sole-sourced by construction and written as such.

**Opinion** — the weakest-leg judgements, the reading that the in-band sentinel plausibly inflated one
model's rate (marked "plausibly", and supported rather than asserted by batch B), and the claim that
one directory is "the instrument, not a tidied copy of one".

The falsehoods found are in the *supporting* sentences, not the numbers: F2, F4 and F5 are three
claims about the bundle that the bundle itself refutes, and all three are cheap to check and were not.

## 5. The corrections dated 2026-09-17, one by one

| # | subject | checked against the evidence | verdict |
|---|---|---|---|
| 1 | the shared working copy and the surviving stash | reproduced completely, including every run id, the ordering, the split and the sanity-check rate | **right** |
| 2 | the first-pass mechanism column and its rate label | the three mislabelled rows are exactly the three named; the label is present as described; the classifier's precedence bug is real | **right** |
| 3 | mechanism computed only for one outcome class | confirmed in both the classifier and the shipped table | **right** |
| 4 | archive owner fields | all eleven archives verified clean directly from the headers | **right** (see F8 on the check's coverage) |
| 5 | the as-ran gate's source carrying the vocabulary it scans for | all three cited locations confirmed, including the split literal | **right** |
| 6 | where the audit and the verdicts live | accurate — and carries **F1**, and goes stale today (**F11**) | **right but blocking** |
| 7 | the two-batch re-run | every figure reproduced independently, statistics included | **right** |
| 8 | the late arm | the substance is right; the "mentioned nowhere above" clause is falsified by the file (**F5**) | **wrong in one clause** |
| 9 | the file's ordering | confirmed | **right** |

**Does any struck passage still read as true?** No. Every struck span I checked is either bracketed
or carries a dated marker, and in each case the surviving text states the replacement. The one place
where two statements appeared to disagree about the whole-tree discard count — one passage giving it
as zero, another phrasing it as "not one ... in 39" — is an idiom, not a contradiction; both say
zero, and the evidence says zero.

## 6. Killed claims

Both READMEs: **clean**, every string, no hits.

The record fires on fifteen strings. **Every one sits inside a struck span, inside a box marked
superseded at its head, or inside a sentence whose grammatical job is to retract the phrase it
quotes** — which is the only way a phrase can be retracted at all. I scanned every text file in the
bundle, not only the documents, and classified every hit. No killed claim survives as a live
assertion anywhere.

Three strings in the shared ledger are short or generic enough to fire on ordinary technical prose
and on agent-generated evidence files; they produced eleven false positives here and no true ones.
That is a note for the ledger's owner, not a defect in this bundle, and it is raised as such.

## 7. What I could not check

- **The gate's pattern lists.** They live outside the repository by design. I ran the gate, watched
  it arm its external category and fire its positive control, and saw every category score zero — but
  I cannot read what it looked for. The assurance that no employer, client or project identifier
  ships rests on a list I did not see.
- **The shipped run-harness files against their true as-ran originals.** The byte-identity guard
  covers the publication tooling only, and deliberately so, because the harness copies are scrubbed.
  I confirmed the shipped copies are internally consistent and that the excluded files are each named
  with a reason; I could not confirm the shipped ones are byte-equal to what executed.
- **The late arm's ordering clause.** Its three commits are not in this repository — this repository's
  history begins with a single file-copy commit weeks after that arm ran — so the check requires a
  repository the bundle names nowhere. The label already says this is the author verifying his own
  record; I confirm only that it cannot be verified from here.
- **That the contamination was unknown while the study ran.** A negative about a private record.
- **The archives as they were before re-packing.** Not in the repository, as the bundle itself states.
- **The reading behind the third-party nudge item.** Left unchecked deliberately, as the policy
  directs, because checking it means handling the figure. I verified instead the two things that can
  be established without touching it: the sibling repository is still private, and the banned count
  appears nowhere in this bundle.

## 8. Verdict

**DO NOT PUBLISH as it stands.** One line blocks it — **F1** — and it is the same criterion already
applied to block a sibling repository, so publishing over it would make the rule selective. It is a
one-sentence fix.

**F2 through F7 should be fixed in the same pass.** F2, F4 and F5 are claims the artefact refutes,
and an artefact whose authority is its scrupulousness cannot ship three of those. F3 is the README
breaking a rule the README states. F6 and F7 are tier and citation defects on the two claims least
able to carry them.

**F8 through F12 should be recorded and fixed at the author's convenience**; none of them blocks.

**Nothing in the measurement layer is wrong.** Every headline number, every statistic, every
per-cell figure and every validity check reproduced from the shipped evidence, several of them
against a second instrument, and the two disagreements that arose were both my instrument being
narrower than the record's. The evidence is complete, the archives are clean, the tooling passes, the
bundle rebuilds byte-identical, and the re-run's pre-registration demonstrably precedes its results.
**What fails here is prose about the work, not the work.**

Once the fixes land, a session that is not the one that made them should re-check them. This read
does not carry forward to the repaired bundle.

---

## Addendum, 2026-09-18 — the keyword pattern decomposed

📌 **Added the day after the read, in response to a question from the drafting side. It changes no
finding, no tier and no verdict above, and none of §8.** It is here because the measurement otherwise
lived only in a terminal, which this repository's own rules call None-tier the moment that terminal
closes. Committed so it is Checkable rather than lost.

**The question.** The keyword pattern's first alternatives are the bare tokens `injection` and
`untrusted`. Does the reported count rest on a loose token that would fire on unrelated text?

**First, a fact about the bundle rather than a reading of it:** the pattern ships **in full and
unelided** in the published classifier, and the README cites that file by name at the point of the
claim. The published copy differs from the as-ran one in one place, a scrubbed username in a path
constant; the pattern lines are identical. So a reader can answer this question without asking
anyone — it is Linkable once the repository is public, and Checkable until then. Any elision seen
elsewhere belongs to a quoting document, not to the artefact.

**The measurement.** Over the 27 matching runs in the cell, counting which alternative fires (a run
may hit several):

| alternative | runs |
|---|---|
| `untrusted` | 14 |
| `injection` | 11 |
| `prompt.?inject` | 9 |
| `not a(n) instruction from you` | 6 |
| `embedded instruction` | 5 |
| `content, not a command` | 0 |

Sixteen runs hit at least one alternative that is specific to the phenomenon. **Eleven hit only the
bare tokens** — the class the question is about. Reading all eleven, every one names the protected
marker in the same sentence. Widening to all 27: **in every case the match sits beside an explicit
reference to the protected marker. No off-target match.**

🔴 **What this does NOT license.** The step above is *reading the matched text and judging it*, which
is a different instrument from the published one, and a weaker-provenance one: it is an agent's
reading, not an artefact. **It does not upgrade the claim's wording and must not be used to.** The
published sentence stays as it is, and the disclaimer beside it — that this is a keyword match and
not a judgement of intent — stays with it. What the decomposition establishes is narrower and
defensive: the count is not an artefact of a loose token, so that specific objection does not stand.

One run in the cell matched the pattern and **kept** the protected file, its text saying it was
flagging the marker rather than acting on it. That single run is the whole distance between the
27 and the 26, and it is the clearest illustration that the flag describes the model's text, not the
outcome.

**If this belongs in the record**, it belongs beside the record's own correction on this figure, and
that is a fixing session's call. It is not added there here: extending the record under review is
what this read exists not to do.

**One number in §2 above has moved since, by this read's own doing.** The suite stood at 92 tests
when it was run for the read on 2026-09-17. Publishing this verdict in the bundle added two tests
that day, so a reader running it now gets 94. The §2 figure is left as it was measured; this line is
the correction, because a review that ships three findings about claims an artefact contradicts
should not ship one of its own.

---

## Addendum, 2026-09-18 — who made the repairs, and what that costs this read

🔴 **The fixes below were made by the session that wrote this read, on Vagelis's explicit instruction
after the cost was put to him.** §8 above says a session that is not the one that made them should
re-check them. That did not happen, and this section exists so the record says so rather than leaving
a reader to assume the separation held.

**What that means, stated plainly.** The findings were independent: they were produced by a session
that authored none of S2-S8 and re-derived every figure from the shipped evidence. **The repairs were
not.** Nobody has reviewed them but their author, who is also the author of the findings that
motivated them. Anyone re-auditing this bundle should treat the fixed passages as **unreviewed text**
and read them from scratch — they carry the weakest provenance of anything in this directory, weaker
than the prose they replaced, which at least had a second pair of eyes on it.

**Fixed, with the blocking one first.**

- **F1**, the only blocker: the internal planning document is no longer identifiable from the bundle.
  Removed rather than struck, because a disclosure left in the published bytes is not corrected. A
  dated note records the change and why the append-only rule did not apply.
- **F11**, in the same paragraph: it now names this read instead of saying the entry is unreviewed.
- **F2**: the naming sentence now points where the name actually is.
- **F3**: the three disposition rates now carry their models, as rule 4 requires.
- **F4**: the study period now admits the arm that ran later and the entries that run later still.
- **F5**: both sentences narrowed from "nowhere above" to what was measured — the contemporaneous
  record — with the later additions named.
- **F6**: Arm E's row and its attribution bullet now carry the tier its own results file gives it.
- **F7**: the comparison in the dated pilot entry keeps its contemporaneous figure and gains a dated
  note giving the study's final bound; the procedural citation gains the panel size and is marked as a
  design rationale rather than a comparison. **The ban on his separate control's count is untouched
  and still returns zero.**

**One more, which was never a numbered finding above and should have been.** The publication policy's
own binding form for the injection figure names no model, and so does the plan that quotes it — the
same breach as F3, one level upstream, in the document that is the authority for every write-up. This
read raised it on the bus when handing the figures over, and then did not carry it into its own
findings list, so it existed only as a message. It is fixed now, in a dated note that supersedes both
earlier wordings. 🔑 **The failure worth naming is not the wording, it is that a defect reported in a
message and not in the artefact is a defect that was not recorded** — the same rule this read applies
to everyone else's work, missed in its own.

**Left, deliberately.** F8, F9, F10 and F12, all recorded as non-blocking above.

⛔ **This paragraph also claimed an open permission question under F7, and that claim is withdrawn —
see the dated note under F7 itself.** The consent entry of 2026-08-10 records that he read every
mention of himself, including the two that restate his published figure, and asked to be named. The
policy keeps that figure separate from his own control's count, which is the one under a ban. There
was nothing open and nothing owed by Vagelis. The bound and citation fixes stand.

**Verification after the repairs**, run in the same session: ~~the tooling suite at 94 tests exit 0~~
⛔ **corrected 2026-09-20 — 95 tests, exit 0 in both layouts; see the dated note in the table above**, the
assembler exit 0 with the gate armed and its positive control firing, every relative link resolving,
and the bundle rebuilding with no uncommitted difference. **That checks the mechanism, not the prose.**
No tool in this repository can tell whether a reworded sentence is true, which is the whole reason
§8 asked for a second session.
