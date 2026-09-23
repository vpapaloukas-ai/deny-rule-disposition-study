# release-tooling/

**`release-tooling/` was written on 2026-09-17, after the study, for publication; the study did not
use it.** `harness/` holds the scripts the study used to run, check and analyse its arms, scrubbed
as described under Placeholders; `harness/measured/f12-trust.sh` also had two lines cut before
release, marked in the file.

The pre-publication release scripts (the bundle assembler, the transcript scrub, the release gate
and their allowlist) are not published. The scrub rewrote their own rules inside their published
copies, and the assembler did not stop the build when the gate failed. The files here replace them.

## Files

| file | what it does |
|---|---|
| `assemble-public-bundle.sh` | Builds the bundle from the private record: scrubbed docs and results, the allowlisted scripts, the transcript archives. Exits non-zero if the gate or the link check fails. |
| `bundle-stopword-gate.py` | The release gate. Reports categories and counts, never matched strings. Blocks on any category hit, on an archive it cannot read or that holds no files, and on owner metadata in archive headers. |
| `check-links.py` | Fails on any relative Markdown link in the bundle that does not resolve inside it. |
| `repack-tarballs.py` | Re-packs archives with neutral owner fields, every member unchanged; replaces nothing unless every archive verifies. `--check` verifies archives against a manifest. |
| `REPACK-MANIFEST.txt` | Per-member SHA-256 of each transcript archive, before and after re-packing. |
| `analyse-rerun.py` | The analysis fixed in section 6 of the 2026-09 re-run's pre-registration, over the shipped archives: run-record checks, per-cell figures, and the Fisher exact tests with Holm correction. |
| `rederive-n50-from-tarball.py` | Recomputes `results/n50/n50-rederived.json` from the shipped n=50 archive with the study's own classifier, and derives, per run, whether a git stash left by an earlier run was visible to the model. |
| `scrub-lib.sh` | The scrub rules, sourced by both scripts that scrub. |
| `scrub-n50-transcripts.sh` | Stages, scrubs, verifies and packs run transcripts, with neutral archive owners. |
| `RELEASE-ALLOWLIST.txt` | The only list of scripts and tooling that ship. Every file in `harness/` is either listed or named there with the reason it does not ship. |
| `test_release_tooling.py` | Red, then green, for every change above. |

## Tests

    python3 test_release_tooling.py -v

A **red** test runs the pre-publication script and asserts that the defect is present, so a green
result cannot come from a test that cannot see the defect. A **green** test runs the file here on
the same input and asserts the fix. The pre-publication scripts are not in the published bundle,
so there the red tests are skipped and say so.

The tests are hermetic. They write their own fake patterns and identifier files, and never read
the real ones, which hold personal values and stay outside the repository. As a result the tests
show that the mechanisms work, not that any particular bundle is clean. The build's gate run
answers that question, and only with the real files present.

## What none of this can establish

The gate matches strings. It cannot detect a disclosure written as an accurate, unremarkable
sentence, and it does not read git history. A clean build is necessary for publication, not
sufficient: the allowlist and a read by someone who did not write the scrub are the other two
conditions.
