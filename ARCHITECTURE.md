# Architecture

A single HTML file with all JavaScript and CSS inlined. No build step at
runtime, no dependencies, and no network requests once loaded — except two
opt-in, off-by-default paths a user can turn on for themselves: external OCR
(an API key and endpoint of their own, read from a local file — see module 12)
and Google Drive sync (their own Google account, narrowest possible scope —
see "Google Drive sync" below). Neither runs unless deliberately switched on.

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
10-bank.js        Bank table, detail view, editing, review queue, hand entry
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

Database `mcq_mastery`, schema version 4.

| Store | Key | Indexes |
|---|---|---|
| `courses` | `id` | — |
| `questions` | `uuid` | courseId, qid, status, fingerprint, batchId, sourceId, nextReviewAt, domainId, canonicalUuid, caseStudyId |
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
| `caseStudies` | `id` | courseId |

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

## Two banks, one register

A question written against a one-to-two-page scenario is not a question without
the scenario. Drawn into Learning, Weak topics, Spaced repetition or a game it
arrives stripped of the only thing that makes it answerable — so case-study
questions are a **separate bank**.

Separate to the user; not separate underneath. The *passages* get their own
store (`caseStudies`); their *questions* stay in `questions`, carrying a
`caseStudyId` and a `caseSeq`. That way versioning, duplicate detection,
attempt history, mastery, the QID register, the backup package, folder and
Drive sync and the merge engine all apply to them without a second
implementation to keep in step.

The separation is enforced at exactly one place:

```js
function isCaseQuestion(q) { return !!(q && q.caseStudyId); }
function eligiblePool(all)     { return all.filter(q => isPracticeEligible(q) && !isCaseQuestion(q)); }
function caseEligiblePool(all) { return all.filter(q => isPracticeEligible(q) &&  isCaseQuestion(q)); }
```

`eligiblePool()` is the only pool every practice mode, every game
(`gameQuestions()`) and both readiness counters draw from, so that one line
excludes case-study questions from all eight existing modes and every
registered game at once — including modes and games added later, which is the
point of putting it there rather than in each of them.

Two callers reach the other side, both explicitly: a timed mock when the
candidate has asked for a case-study section, and the `casestudy` mode, which
is marked `caseBank: true` in `MODES`.

`null`/absent `caseStudyId` reads as standalone, so every record written before
this existed needs no migration.

**Whole scenarios only.** `pickCaseBlock()` never returns part of a case study:
three of a scenario's five questions means reading two pages for a fragment.
Which whole scenarios to take is a subset-sum over their sizes — every total
reachable by some set of whole cases, and the one closest to the number asked
for, ties going to the smaller total. Greedy selection was tried and is wrong in
both directions: cases of 4, 6 and 3 asked for 10 land on 7 while 4 + 6 sits
there, and asking for 1 from a bank of fives lands on 0. The empty set is
excluded, so a request for a case-study section always produces one. The number
actually reached is reported rather than assumed (`describeCaseBlock()`).

The block is appended after the standalone selection, contiguous and in
`caseSeq` order, and `session.caseSection` records where it starts. When
`caseCount` is 0 — every mode but an opted-in mock — the selection path is
byte-identical to what it was before any of this existed.

**Only case-level filters reach the case pool.** A per-question filter (a
domain, a difficulty, "never attempted") would remove *some* of a scenario's
questions and hand back a case that is no longer whole, which is the one thing
this is for.

**A scenario nobody can read is not one anybody can be asked about.**
`caseEligiblePool()` answers "is this question itself ready";
`drawableCasePool()` answers "can it be asked", which additionally requires the
scenario to exist, not be archived, and have text. Every draw and every
readiness count uses the second — otherwise an import that found a case
reference but no passage produced questions the app warned about and then drew
anyway.

**A staging candidate is already in the case bank.** `isCaseQuestion()` reads
`caseRef` as well as `caseStudyId`, because a candidate on the staging screen
knows its scenario but that scenario has no id until admission. Reading only
`caseStudyId` put every incoming case-study candidate in the standalone bank
for exactly as long as duplicate detection had to run, which switched it off
for the case that matters most: re-importing a file.

**Duplicate detection is partitioned** by `comparablePair()`. The same wording
can honestly appear once in the abstract and once about a specific scenario, and
pairing those puts a row in the review queue that neither side can resolve. Two
case-study questions still pair, including across different scenarios, because
that is a real duplicate.

**Spaced repetition never surfaces one**, by construction rather than by rule:
it filters `eligiblePool()`. Anything due surfaces inside Case study practice.

## Marking, and the two things frozen with a paper

Accuracy — a proportion of questions — is the *learning* metric, and mastery,
weak topics and the spaced-repetition ladder all still run on it untouched, so
a two-mark question is not treated as twice as worth revising. Marks are the
separate *exam* metric.

`marksOf(q)` resolves a question's own value, else the course's case-study or
standard rate. `markSession(s, byId)` returns the earned, deducted and net
marks, the percentage, the verdict, the margin and the scaled score.
`sessionScore()` gained these as extra fields rather than being replaced, so
every existing caller is unchanged. At the defaults — one mark a question, no
deduction — marks and the question count are the same number and `plain` is
true, which is what keeps the marks column, the marks tile and the deduction
line off screen for anyone who has not configured anything.

Two things are fixed on the session at the moment the paper is made:
`session.marks` (what each question was worth) and `session.marking` (the pass
percentage, deduction and scaled mapping it is read under). Re-pricing a
question, or discovering next month that your exam deducts a quarter for a
wrong answer, must not silently re-mark papers already sat — the same reason
an attempt has always recorded the `questionVersion` it was answered against.
Attempts additionally carry `marks` and `awarded`, so an attempt log read years
later still adds up to the score reported at the time.

`toScaledScore()` maps piecewise about the pass mark, so the pass percentage
lands exactly on the pass score. That is the only property of the mapping
anything relies on; a board's real equating is undisclosed and this does not
pretend otherwise.

## Reading time and confidence back

Both were recorded from the beginning and reported as a single average and not
at all respectively.

`timeSplit()` divides answers four ways on correctness and the **median**
question time. Median, not mean: one question someone walked away from drags a
mean far enough to file genuinely slow answers on the fast side. Strictly
greater counts as slow, so a paper with no variation lands entirely on the fast
side rather than being cut arbitrarily in half. Answers with no recorded time
are excluded and counted separately rather than treated as instant.

`calibration()` groups attempts by what the person claimed. What each level
claims is derived from the `CONFIDENCE` weights the scheduler already uses, so
there is one definition rather than two that can drift, floored at 0.25 because
guessing between four options is right that often by luck. Attempts with no
confidence — every answer in a timed mock, which deliberately asks nothing —
are excluded rather than bucketed as unknown, and `calibrationVerdict()`
returns null below five answers rather than calling a habit off a handful.

## The distractors

An option is `{ id, text }` and optionally `rationale` — why *that* option is
right or wrong. `makeOption()` omits the key entirely when there is nothing to
say, so it never appears as an empty string on every option of every record. It
counts in `materiallyDifferent()`, so editing one earns a version like editing
the explanation does.

`distractorProfile(attempts, q)` reads back the `selectedOptionId` every attempt
has always carried. It counts by option **id** and reports by option **text**,
because letters move with the shuffle and "you keep choosing C" is meaningless
across attempts where C was a different sentence each time. An option a later
edit removed is counted as `unmatched` rather than dropped, so the totals still
add up to the attempts that happened.

`dominant` requires at least two picks *and* more than every other wrong option
put together — strictly more, not equal. One miss is not a pattern and a tie is
someone guessing; claiming either is a belief would be putting words in their
mouth. `repeatMissLine()` returns null rather than a weak sentence whenever
there is nothing solid to say.

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

**This runs at every point a question's content can change, not only at
import.** `recheckQuestion()` is called after every save, admission, merge and
unmerge, and re-evaluates that question against the whole live bank — a
conflict or duplicate found this way is recorded on *both* sides
(`conflictWith` / `dupWith`, arrays of uuids), and both are pulled out of
practice, whichever one triggered the check. Import-time detection is one
caller of this, not a separate mechanism: a candidate matched against the bank
during staging gets the same symmetric treatment once admitted. A pair either
side has explicitly dismissed ("keep separate") is recorded in
`dismissedPairs` and never re-raised. `rescanCourseForPairs()` (Question Bank
→ "Rescan for conflicts") sweeps the whole course once, for data that
predates this or was edited outside the app. The review queue states the
actual disagreement inline — which option each record claims is correct —
rather than just naming the other record.

Within a batch, each processed candidate joins the live index, so a batch is
checked against itself without a growing linear scan.

## Import pipeline

```
file(s) → readFile() → extractor (docx/xlsx/pdf/csv/json/txt)
        → columnMapDialog() when a spreadsheet header is unrecognised
        → parseText() / rowsToCandidates() / jsonToCandidates()
        → candidates with per-field confidence (+ caseRef / caseSeq)
        → candidateToQuestion() + fingerprint
        → duplicate detection against the bank (within its own partition)
        → staging screen (preview, per-item decisions, scenario editing)
        → admitBatch() → case studies written → QID allocation → written
        → reconciliation report
```

### The contract is stated, not implied

`IMPORT_FIELDS` is the single description of every importable field: its name,
whether it is required, its spreadsheet headings and its JSON keys.
`COLUMN_ALIASES` is derived from it, `jsonToCandidates()` reads through it
(`JSON_ALIASES` / `jsonPick`), and the reference panel on Add Questions is
rendered from it. The app therefore cannot advertise a column it does not read,
or read one it does not advertise. The case fields (`caseRef`, `caseTitle`,
`caseText`) are marked `caseField` and excluded from `JSON_ALIASES`, because
inside a *question* object `title` and `text` mean something else.

A spreadsheet whose header matches nothing used to fall silently through to
positional guessing. It now opens `columnMapDialog()`: every column with the
values actually in it, a dropdown per column, whatever the header *did* match
pre-filled, and a deliberate "no header row at all" escape to the positional
reading. `rowsToCandidates(rows, opts)` takes that mapping; called with no
second argument — every pre-existing caller — it behaves exactly as before.

### Case studies through the same pipeline

JSON nests each scenario's questions inside it, which is the shape in which the
link cannot be lost. A spreadsheet groups rows by a shared `caseRef`, taking the
first non-empty `caseText` under that reference, so a two-page passage is pasted
into one cell rather than repeated down every row. Scenarios are keyed by
*file plus reference* through staging, since two spreadsheets in one batch can
each call their first case "1". `admitBatch()` writes the scenarios **before**
the questions, and only those that actually keep a question, so a case-study
question is never in the bank pointing at a case study that does not exist.

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

Version 4 added the `caseStudies` store and the `caseStudyId` index. Bumping it
is the point, not a side effect: the same number goes into the data file, so an
older copy of the app now stops with "written by a newer version" rather than
opening a bank whose case studies it would silently drop on its next snapshot.
`syncStores()` derives from `STORES`, so the new store reached the data file
and both sync backends without being listed anywhere; `BACKUP_STORES` and
`mergeBankPayloads()` name their stores by hand and were updated.

## Google Drive sync (optional)

A second possible home for the bank, in the user's own Google Drive,
reachable from any device signed into that account. Exactly one backend is
ever the active connection — a local folder or Drive, never both — because
two backends racing to write the same bank is a conflict machine, not a
feature. Connecting one disconnects the other: the file or Drive copy being
left is not touched, only this app's link to it is dropped, and switching
back at any time picks up right where that side left off. `DriveSync.touch()`
and `FileStore.touch()` sit behind the same write hook and each bail out
immediately when their backend is not the connected one, so this is enforced
at the single choke point every write already passes through
(`DB._guard`), not scattered across the UI.

Drive's API has no cheap append the way local disk does — every sync is a
whole-file upload — so writes are debounced (a few seconds after the last
change, sooner if changes keep arriving) rather than journalled instantly.
Not as immediate as the local folder's per-answer journal, but close, and a
long way from a flat five-minute timer. A coarse safety-net timer covers the
rare case where a debounced push is lost (a backgrounded tab throttling
`setTimeout`).

Treated as closely as Drive's API allows like the local file: connecting
reads what is already there, offering the same reconciliation choice the
local folder's `connectFlow()` uses (`_reconcileOnConnect()`) — see "Merging
instead of choosing" below; merge is the default there, not an all-or-
nothing pick. Every later boot checks Drive's `modifiedTime` — a metadata-
only call, not a download — against what this browser last recorded; a
newer remote copy is loaded in automatically, the same way opening the app
just reads the local file. It only asks first when this browser *also* has
changes that never reached Drive (tracked as a `driveDirtySince` flag in
`fsmeta`, set the moment a write is pending and cleared on a successful
push) — a genuine conflict, not routine catching-up, mirroring how the
local folder only asks when a file changed under it *and* something was
still unsaved. A manual "Load from Drive" and "Sync now" remain in Settings
for forcing either direction early, and "Sync with Drive" (below) offers a
one-off merge without switching away from a connected local folder.

Every one of these reconciliation choices backs up whichever side is at
risk before it acts — not just a note saying nothing was deleted. Discarding
this browser's bank, or merging (a merge can still overwrite a same-key
record with the other side's newer version), runs the same
`requireSafetyBackup()` used before a replace-restore or a course wipe;
discarding Drive's copy, or an existing local file connected to without
being loaded — content that was never in this browser's IndexedDB to begin
with — runs `requireExternalBackup()`, which builds the same backup ZIP
shape (`buildBackupFromPayload()`) directly from that content and downloads
it. Every path blocks its next step if the backup fails, and asks a final
"Continue" before proceeding even when it succeeds. Merge is styled as the
primary action in these dialogs; the two "keep only one side, discard the
other" choices are both styled as danger — not "keep the bigger bank is
primary, overwrite is danger" as a two-choice version of this dialog used
to be, since merge itself is now the safe default and either single-sided
choice is a deliberate discard.

`DriveSync.driveLossCheck()` is Drive's mirror of `FileStore.lossCheck()` —
the last line of defence in `push()` itself, independent of any dialog.
It tracks the last known remote question count (`_remoteQuestionCount`,
persisted as `driveQuestionCount` in `fsmeta`) and refuses a push that
would silently collapse it — an empty or badly shrunken local bank pushed
by a stray auto-sync, not a deliberate choice. The explicit "overwrite
Drive" choice in the reconciliation dialogs calls `allowDriveShrink()`
first, the same one-shot consent pattern `FileStore.allowShrink()` uses.

Auth is Google Identity Services' token client: no backend server, no client
secret (a static page cannot keep one confidential), no long-lived refresh
token stored anywhere. `DriveSync.accessToken` is an in-memory property only —
never written to IndexedDB, the snapshot file, or any export — so it is gone
on reload and silently re-requested next time, succeeding only if the browser
still has an active Google session and prior consent. The `drive.file` scope
requested is Google's narrowest: the app can only ever see files it created
itself. Only the Drive file's id, a connected flag, and the last-synced
`modifiedTime` are persisted (in `fsmeta`, alongside the folder handle,
exempt from every export for the same reason). An OAuth client ID identifies
the app to Google, not any one person — it is not a secret, and only works
from its registered origin(s) — so it needs setting up once per deployment,
not once per visitor: `DEFAULT_DRIVE_CLIENT_ID` holds it for whoever deploys
this copy of the app, and every other visitor just sees "Connect Google
Drive" with no setup screen at all. `effectiveDriveClientId()` falls back to
a per-browser override in Settings, for a fork running from a different
origin. Settings → "Where your data lives" has the one-time Cloud Console
walkthrough, shown only when no client ID — default or override — is set.

Read-only enforcement (`_writeVeto`) stays local-folder-only: a Drive push
that fails leaves the change sitting in IndexedDB to retry, rather than
blocking editing outright the way a missing local file does. Drive's failure
modes are ordinary network flakiness, not the "silently diverging from a
file you think is being written" risk the local guard exists for, and
blocking edits over a transient network blip would cost far more than it
protects. `DriveSync.status()`/`problem` still surface a failed sync clearly
in the top bar and Settings, so a real, lasting failure is never silent —
just not a hard stop.

Existing installs from before this backend split — a local folder and Drive
both recorded as connected — resolve on the first boot after updating: the
local folder wins, Drive is disconnected (its file is untouched), and a
one-time toast explains why. Reconnect Drive from Settings to switch.

## Merging instead of choosing

Every point where this browser's state and a payload from somewhere else
(Drive, or an existing local file) meet used to force an all-or-nothing
"keep this / keep that" pick. `mergeBankPayloads()` (and its write-through
partner `applyMergedBank()`) combine the two into one bank that keeps
everything both sides hold, and it is the default action in every
reconciliation dialog that reaches it — "keep only one side" remains
available in the same dialog, styled as danger, as a deliberate escape
hatch, not the default.

It covers, without any dialog needing its own bespoke merge logic, every
point local and remote content can meet:

- First-ever connect to a local folder, or to Drive, when this browser
  already has data of its own (`connectFlow()`'s "There is already a bank
  in that location", `DriveSync._reconcileOnConnect()`'s Drive equivalent).
- Switching backends (local → Drive, Drive → local): the switch flow
  disconnects the old backend first and lands in one of the two dialogs
  above, so no separate code path was needed for this case.
- "Sync with Drive" (`DriveSync.syncBridge()`), a new one-off action next
  to a connected local folder's other buttons in Settings — pulls Drive,
  merges, writes the merged bank back to both the local file and Drive,
  then leaves Drive exactly as disconnected as before the call. The local
  folder stays the one persistent connection throughout; this never makes
  Drive the active backend the way `driveConnectFlow()` does.

Merge strategy is deliberately different per store, because "newest wins"
is not a safe default for every one of them:

- **questions, courses, sources, batches, presets, notes, caseStudies** — keyed rows;
  newest `updatedAt` (falling back to `createdAt`) wins on a shared key,
  every key unique to one side is carried over untouched. Merged questions
  are then re-checked with the existing `rescanCourseForPairs()` sweep, so
  a genuine disagreement the merge surfaces — the same stem admitted
  independently on two devices, or two answer keys that now disagree —
  lands in the review queue via the ordinary conflict/duplicate machinery
  instead of one side silently winning.
- **sessions** — the same newest-wins keyed merge, not append-only: a
  session has a real `id`, not an auto-increment one, and the same session
  can genuinely be touched from two devices (started on a phone, resumed
  later on a laptop).
- **attempts, questionVersions, audit** — append-only logs whose keys are
  auto-increment integers assigned independently by each IndexedDB, so the
  same integer on both sides is almost never the same real event. These
  merge by matching content (`sessionId`+`questionUuid`+`ts` for an
  attempt, `questionUuid`+`version` for a version snapshot) instead,
  never by the colliding key.
- **tombstones** — union by `qid`, no time comparison. A retirement
  recorded on either side is retired everywhere; it is never un-retired.
- **idRegister** — deliberately never "newest wins". That could roll the
  Question ID watermark backwards and let `IdRegister.next()` re-issue an
  id already assigned, on the other side, to a different question. The
  higher `lastSeq` always wins; both sides' allocation histories are
  unioned underneath it and re-capped at 500 entries, same as
  `IdRegister.next()` itself does.
- **settings** — not merged key-by-key. A device's preferences are one
  coherent set, not independent facts, so whichever whole payload has the
  newer top-level `savedAt` is adopted wholesale.
- **images** — keyed union, no time comparison — captured once, never
  edited after.

`applyMergedBank()` writes through the ordinary guarded `DB.putMany()` path
(not the raw, untracked writes `loadFromDisk()`/`_applyRemote()` use to
rebuild IndexedDB from a file that is already the source of truth) so
whichever backend is actually connected at the time picks the change up
through its normal dirty-tracking and pushes/flushes it out afterward,
exactly like any other edit. It forces `FileStore._cache` to rebuild from
scratch immediately after writing, since `FileStore.touch()` — the thing
that would normally mark stores dirty for the next `buildPayload()` call —
only fires when `FileStore` itself is the connected backend, which is not
true for a Drive-only merge; without that reset, a push right after the
merge could silently upload the pre-merge snapshot.

## Course notes (optional)

A place for a student's own revision material — a scanned handwritten module
summary, anything worth a quick look right before a practice session — kept
per course and optionally tagged to a blueprint domain.

A note's *bytes* live wherever the bank already lives: a `notes` subfolder
next to a connected local folder, or its own file in Drive when that is
connected, never duplicated into IndexedDB on top of that. Only with neither
connected does a note's content sit in IndexedDB directly (as a data URL),
capped by `notesMaxKB` — the same trade-off images already make. The `notes`
object store itself holds only metadata (title, domain, topic, size, where the
bytes actually are) plus that fallback content field, and syncs like any other
store.
