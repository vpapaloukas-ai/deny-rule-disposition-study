# Raw evidence, scrubbed transcripts

Agent sessions as recorded at run time: every tool call, tool result and oracle value.

These are **scrubbed** copies. The private originals stay private and are not part of any
release.

## What is here, precisely

| tarball | what it holds |
|---|---|
| `n50-disposition-300-runs.scrubbed.tar.gz` | 🔑 **the 300 runs behind the headline**, 3 models × 2 arms × 50, each with its full session transcript, oracle verdict, pytest output, canary result and metadata |
| `rerun-2026-09-600-runs.scrubbed.tar.gz` | 🔑 **the 2026-09-17 re-run**, the same six cells in two pre-registered batches, 600 runs, each with the same per-run material. See `rerun-2026-09/` |
| `arm-a-results`, `arm-b-results` | the **superseded n=10 Opus pilots** |
| `arm-c-results`, `arm-d-results` | the cost side and the rule-mechanics probes |
| `phase2-results` | the OS-sandbox phase |
| `gen-c-session`, `gen-d-session` | the two blind generator sessions that produced the frozen inputs |
| `substrate-build` | the test substrate's construction |
| `wall-logs` | the behind-the-wall oracle logs |
| *(Arm E)* | 🔴 **nothing.** See the note below. |

> 🔴 **Arm E has no archive here, and this section did not say so until 2026-09-20.**
> `results/arm-e/` ships Arm E's pre-registration, its results and both controls, but there are no
> raw session transcripts for it in this directory or inside any archive in it — measured across all
> eleven, zero entries. Of the rows in the bundle README's result box, Arm E's **5/10** is therefore
> the one figure a reader cannot recompute from shipped session evidence. The table above lists what
> is here, and Arm E was simply absent from it, which is the same silence this file already carries a
> correction for below.

> ⚠️ **This section used to claim "the complete raw evidence behind the study: every agent
> session."** That was false when written. The bundle then contained raw transcripts for the
> *superseded pilots* and **none at all for the n=50 batch**, so the three numbers the study
> leads with were the only ones a reader could not audit from raw evidence, which is the exact
> opposite of this repository's purpose. It was corrected before publication; the review that
> caught it left no committed record. The 300 runs were added rather than the claim narrowed.

> **Re-packed 2026-09-17.** The archives of the 2026-08-08 study were re-packed on this date to
> clear the owner fields in their tar headers, which carried a local account name that the scrub
> never saw because it rewrites file contents. The author checked that every file inside is
> byte-identical to the archives as they were committed on 2026-08-07 and 2026-08-08, with per-file SHA-256 digests
> kept in `release-tooling/REPACK-MANIFEST.txt` and re-checkable with
> `release-tooling/repack-tarballs.py --check`. The earlier archives are not in this repository, so
> that comparison cannot be repeated here. The runs themselves took place 2026-08-06 to 2026-08-08.
> The re-run's archive was packed with those fields already cleared.

> 🔴 **Redacted 2026-09-23, and this is the one place the evidence itself was changed.** One phase-2
> probe, `P07_E3_1`, ran `git clean -fdx` in the test repository under the sandbox. git printed each
> path it could not remove because the sandbox held it busy, and those paths are named like the
> operator's user configuration: shell, editor and agent settings. That output shipped in
> `phase2-results` and in `wall-logs`, in the probe's `stream.jsonl` and in `run-rows.json`. In those four files the list is replaced by a
> marker that gives the date and the line count: 20 lines, twice per transcript, and a 3-line
> truncated excerpt in each `run-rows.json`. The command, its exit status, the lines naming the test
> area, and everything else the agent did are unchanged. `REPACK-MANIFEST.txt` records the new
> digests for exactly those four members and two archives, and `--check` verifies them. The
> unredacted bytes stay in the private record.

## What was scrubbed

Verified by re-scanning the scrubbed output, and again across the whole repository at assembly
time by `release-tooling/bundle-stopword-gate.py`, which reads inside these tarballs, including
their member names and owner metadata. **From 2026-09-17, a hit stops the build.**

| category removed | replaced with |
|---|---|
| personal email address | `dev@example.invalid` |
| local operating-system username, and any path containing it | a generic placeholder |
| local repository paths | `<repo>` |
| the harness's own session and event identifiers | `<uuid>` |

*(A third party's name was on this list until 2026-08-10, when he asked to be named. He is named in
`docs/`, where the record cites his work; the bundle README records the consent without repeating the
name. Measured, not assumed: the 2026-08-08 archives mention him under neither
form, so nothing in them changed.)*

**Deliberately NOT removed, and named here so the table above is not read too broadly:** the
model provider's own opaque correlation identifiers, the request, message and tool-use ids, are
**left intact throughout**. They carry no user content and identify nothing outside the provider's
own systems, and they are useful provenance for anyone reproducing a run. An earlier version of this
table said "session and event identifiers" without qualification, which read as covering them and was
therefore **false as written**.

**Kept on purpose:**

- The author's public brand and website, for attribution. These appear inside the transcripts
  wherever an agent read the template's own README during a run, which is ordinary evidence.
- The fabricated `@example.com` addresses in the test substrate. Reserved-for-documentation,
  not real.
- The commit co-author trailer.
- All the actual evidence: commands, tool results, oracle values, outcomes. Nothing about what
  an agent did or why was altered. *(One exception since 2026-09-23: the list of sandbox-held
  configuration paths redacted from one phase-2 tool result, described above. What the agent did and
  why is unchanged.)*

## One caveat worth stating

Scrubbing is a pattern substitution over the files in these archives. It was verified by a scanner
that carries a **positive control**, a string that must be found, because a scanner that reads
nothing reports zero hits and looks identical to a clean result. That failure has already happened
once here: a rebuild emptied this directory, and the verifier duly certified the empty directory as
clean. From 2026-09-17 the scanner also fails on an archive it cannot open or that holds no files.
