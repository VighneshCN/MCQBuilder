# Architecture

A single HTML file with all JavaScript and CSS inlined. No build step at
runtime, no dependencies, no network requests once loaded.

Source is maintained as 17 modules concatenated in numeric order into the
`<script>` block of `index.html`. Editing `index.html` directly works; keeping
the modules and re-concatenating is easier to maintain.

```
01-core.js        DOM helpers, IndexedDB DAL, settings, hashing, RNG
02-model.js       Courses, statuses, blueprints, QID register, repositories
03-dedupe.js      Fingerprinting, similarity, duplicate detection
04-extract.js     ZIP/DOCX/XLSX/PDF/CSV extraction, file routing
05-parse.js       Text and row parsing into question candidates
06-learning.js    Mastery, spaced repetition, weak-topic scoring
07-session.js     Practice modes, selection, blueprint weighting
08-shell.js       App shell, routing, navigation, theming
09-practice.js    The practice runner
10-bank.js        Bank table, detail view, editing, review queue
11-import.js      Add Questions, staging, reconciliation, admission
12-image.js       Image intake, crop/rotate/adjust, transcription
13-analytics.js   Performance analytics and error-cause breakdown
14-backup.js      Export, restore, safety backups, integrity checks
15-settings.js    Settings, course management, diagnostics
15b-filestore.js  The file-backed database
16-tests-boot.js  Test suite and boot sequence
```

`15b` is deliberately named to sort before `16`, because the boot sequence at
the end of `16` depends on it.

## Two layers of storage

The design separates *where the data lives* from *what makes it fast*.

**The JSON file in your chosen folder is the source of truth.** It holds
everything — questions, attempts, sources, sessions, settings, audit trail.

**IndexedDB is the working copy.** It provides the indexes that make filtering
and session selection fast, and it is rebuilt from the file on every launch. It
also holds the folder handle, which is the one thing never written to the file.

If no folder is connected, IndexedDB is all there is, and the export in Backup &
Restore is the only safety net.

### Object stores

Database `mcq_mastery`, schema version 2.

| Store | Key | Indexes |
|---|---|---|
| `courses` | `id` | — |
| `questions` | `uuid` | courseId, qid, status, fingerprint, batchId, sourceId, nextReviewAt, domainId, canonicalUuid |
| `questionVersions` | auto | questionUuid |
| `sources` | `id` | courseId, fileHash |
| `batches` | `id` | courseId |
| `attempts` | auto | questionUuid, sessionId, courseId, ts |
| `sessions` | `id` | courseId, status, startedAt |
| `settings` | `k` | — |
| `audit` | auto | ts, entityId, action |
| `images` | `id` | — |
| `idRegister` | `courseId` | — |
| `tombstones` | `qid` | — |
| `presets` | `id` | courseId |
| `fsmeta` | `k` | — |

Every course-owned record carries `courseId`. There is no global question pool;
switching courses is a filter, not a migration.

`fsmeta` holds the folder handle only. It is excluded from every export and
every write to the data file, and it is exempt from the read-only guard —
recording a reconnection must work while the app is refusing everything else.

## Writing: journal plus snapshot

Answering one question produces about 1.6 KB of new information. Rewriting a
multi-megabyte file for that is absurd, so writes follow the pattern databases
have used for decades.

**Journal.** Each change appends a line to `mcq-mastery-journal.jsonl`.
Debounced 700 ms. Cost is proportional to what actually changed.

**Snapshot.** The whole bank is rewritten to `mcq-mastery-data.json` when a
session ends, after an import, when the tab closes or is hidden, when the
journal passes 400 KB, or on a timer. The journal is then emptied, because the
snapshot supersedes it.

**Load.** Read the snapshot, then replay the journal on top. The two together
are always the complete picture.

The snapshot timer scales with file size — 10 minutes below 4 MB, 30 minutes
below 15 MB, hourly above — because a snapshot costs in proportion to its size
and the journal already holds everything in between.

Some changes escalate straight to a snapshot rather than being journalled: a
cleared store, a bulk write of more than 40 records, or any bulk write to an
auto-increment store, where per-record keys cannot be captured reliably.

A truncated final line in the journal — the tab closed mid-write — ends the
replay cleanly and keeps every complete entry before it.

## Protecting the file

Everything here exists because a silent failure is worse than a loud one.

**Identity tracking.** After each snapshot the file's size and modification time
are recorded. Before every write, and every 30 seconds, and whenever the tab
regains focus, the file is checked against that record.

- *Gone* → stop writing, go read-only, ask. It will not silently recreate a file
  you may have deleted deliberately.
- *Changed by something else* → stop, show both versions side by side, ask which
  to keep. A sync client rewriting identical bytes is distinguished from a real
  edit by comparing the file's internal `savedAt`, so identical content with a
  new timestamp does not raise a false conflict.

**Never create what should already exist.** Once a file is known to exist, the
write path opens it with `create: false`. A deletion fails loudly instead of
being papered over.

**Loss guard.** A snapshot holding zero questions, or fewer than half what the
file already holds, is refused. Deliberate reductions arm a one-shot consent
flag, consumed by the save it was granted for.

**Verify after writing.** Every snapshot is read back and must parse, contain
its stores, and hold exactly the expected question count before it is trusted.

**One generation of rollback.** The previous verified snapshot is written to
`mcq-mastery-data.previous.json` before the main file is replaced.

**Mandatory backups before destruction.** Deleting a course's questions or doing
a replace-restore runs a full backup first and verifies it landed. If it fails,
the destructive operation is abandoned.

## Question identity

Human-readable IDs (`CISA-Q-000042`) are allocated from a per-course register at
the moment a question is *admitted*, not when parsed or staged. Sequence numbers
are never reused; deleting a question writes a tombstone keyed by its QID so a
retired ID can never be handed to a different question.

The internal key is a `uuid`; the QID is a label. Nothing joins on QID.

## Duplicate detection

Three layers, cheapest first:

1. **Exact fingerprint** — SHA-256 over the normalised stem plus sorted
   normalised option texts.
2. **Near-duplicate** — token-set and character-shingle similarity, with option
   overlap as a secondary signal.
3. **Answer conflict** — two questions that match but state different answers
   are flagged and both held out of practice. This is the case worth catching.

The inverted index buckets on *rare* tokens. Indexing on merely long words meant
common terms like "information" and "following" returned thousands of candidates
per lookup; anything appearing in more than 2% of the bank is now treated as
noise, and the candidate pool is bounded. Exact fingerprint matches bypass those
bounds entirely, so definite duplicates are never missed.

Per-question derived data — token sets, shingles, content keys — is cached on
the question object rather than rebuilt inside every comparison. The cache is
non-enumerable, so it never reaches the data file, and a generation counter
bumped on any question write invalidates it.

Within a batch, each processed candidate joins the live index, so a batch is
checked against itself without a growing linear scan.

## Import pipeline

```
file(s) → readFile() → extractor (docx/xlsx/pdf/csv/json/txt)
        → parseText() / rowsToCandidates() / jsonToCandidates()
        → candidates with per-field confidence
        → candidateToQuestion() + fingerprint
        → duplicate detection against the bank
        → staging screen (preview, per-item decisions)
        → admitBatch() → QID allocation → written
        → reconciliation report
```

The reconciliation report is the point: every question that entered the parser
is accounted for. Low confidence does not block import; it routes the question
to a review status where it is excluded from practice until confirmed.

## Versioning

Editing a question snapshots the old version and increments a counter. Each
attempt records the version it was answered against, so history survives edits
without lying — a typo fix keeps your history attached, and a changed correct
answer leaves past attempts interpretable.

## Option randomisation

Order is randomised per presentation, seeded by session. Questions whose options
reference each other — "All of the above", "Both A and B" — are detected at
import and pinned. Answers are stored as an option **id**, never a letter or
index, so randomisation cannot desynchronise the correct answer from its text.

## Dependency-free file handling

`.docx` and `.xlsx` are ZIP archives, and backup export needs deflate. Rather
than bundle a ZIP library, `04-extract.js` implements ZIP reading and writing on
the browser's native `CompressionStream` / `DecompressionStream`.

PDF is the weak point. The decoder handles simple text-layer PDFs and *fails
loudly* on those it cannot read, having checked its own output is plausibly text
before returning it. Returning garbage that then parses into hundreds of
nonsense questions would be far worse than an error message.

## Migration

`APP.schema` is the IndexedDB version. Store creation is guarded by
`objectStoreNames.contains()` and index creation by `indexNames.contains()`, so
adding either in a future version is additive and safe on existing databases.
The data file carries its own schema version and is refused if it is newer than
the running app.
