# Architecture

A single HTML file with all JavaScript and CSS inlined, plus two small files a
browser refuses to accept any other way: `sw.js`, because a service worker
cannot be inlined, imported from a `data:` URI, or built at runtime; and
`manifest.webmanifest`, because a `data:` URI manifest has no base for
`start_url` to resolve against, so Chrome discards it and the app is not
installable — checked with `Page.getInstallabilityErrors`, which named
`start-url-not-valid` before and reports nothing after. Between them they buy
the app opening with no network and installing as an app. It is fully
functional without either. Everything else remains in the one file. No build step at
runtime, no dependencies, and no network requests once loaded — except two
opt-in, off-by-default paths a user can turn on for themselves: external OCR
(an API key and endpoint of their own, read from a local file — see module 12)
and Google Drive sync (their own Google account, narrowest possible scope —
see "Google Drive sync" below). Neither runs unless deliberately switched on.

Local OCR is not one of those two, and stays local by construction. tesseract.js
is four separate pieces — wrapper script, Web Worker, WebAssembly core and
language data — and the library's defaults fetch the last three from a CDN, so
"local OCR" would have made a 15 MB network request on its first run and failed
outright offline. `resolveOcrEngine()` pins `workerPath`, `corePath` and
`langPath` to the folder holding the script named in Settings, probes that
folder with `HEAD` to see which filenames a given tesseract.js version shipped
(and whether the language data is gzipped), and refuses to run naming the
missing file rather than letting the library reach for a CDN. Where the probe
itself cannot answer — `file://`, where `fetch` is blocked — it runs on the
usual names and retries once with the other gzip setting.

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

And, alongside the file rather than inside it:

```
sw.js             The offline shell — see "Offline" below
manifest.webmanifest   Name, icon and start URL, so it can be installed
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

Difficulty, confidence and correctness are three independent, permanently
recorded facts, and none of the three can overwrite another. The difficulty
self-rating `askConfidence()` optionally asks for is written straight through
onto the *question* (`Session.answer()`), guarded on `difficultyUngraded()`
rather than on the value, so a later attempt — right or wrong — can never
quietly replace a grade someone already gave. Confidence is stored on the
*attempt* untouched by whether the answer turned out correct. Getting a
question wrong after saying "Knew it" does not erase either fact; it is
exactly the case `calibration()` exists to catch, and it is what pulls a
session's calibration verdict toward "overconfident."

## A modal must let go of what it interrupted

Reported from the runner: an option showing a blue outline with nothing
chosen — not the browser painting a state that meant anything, just its
default `:focus-visible` ring (`index.html:104`, the only rule that can
produce a bare outline; a real choice also fills the background, via
`[aria-pressed="true"]`). `.opt` had no focus style of its own to override it.

Tapping an option gives it real DOM focus before `askConfidence()`'s dialog
even opens. That dialog is `sticky: true` — a backdrop tap does nothing, only
Escape or ✕ closes it — and on that path `choose()` returns immediately
without ever calling `render()`, so nothing rebuilds the option list or
touches focus. `modal()` itself only ever removed its own DOM on close; an
element outside the modal that happened to hold focus when it opened was
never its concern. Cancel out of a dialog instead of answering, and whatever
opened it is left wearing a focus ring that no longer describes anything.

Fixed once, at the shared function rather than at this one call site:
`modal()` now captures `document.activeElement` as `opener` before it builds
its DOM, and blurs it in `close()`, on every exit path — confirm, cancel, or
Escape. This protects every dialog in the app that opens from a button, not
only the confidence one, and it is a no-op on the confirm path here
specifically, since `render()` already rebuilds the option list (and destroys
the old, focused node) on that route anyway. `.opt` also gained its own
`:focus-visible` rule — dashed, not solid — so a genuine keyboard focus (an
external keyboard, an iPad) reads as focus rather than as a choice, on top of
the fix that stops a stale one appearing in the first place.

## What blocks practice, and what merely locks a feature

`isPracticeEligible()` reads `STATUS[q.status].practice` rather than naming a
status. That flag had been in the table since the first version and nothing
read it; the gate hardcoded `=== 'active'` instead. Two statuses now carry it:
`needs_class` (no domain) and `needs_content` (the parser was not fully
confident it read the wording). Both describe something **missing**, not
something **wrong**.

This was not cosmetic. `deriveEntryStatus()` files a question as `needs_class`
whenever it has no `domainId`, and `suggestDomain()` can only guess from
`course.hints`, which only the CISA and DISA templates ship. So a course
somebody sets up themselves classified nothing, and every question fell out of
practice. Measured in a browser on a self-made course with a plain question
file: 30 imported, 30 practisable now, 0 before.

`BLOCKING_STATUSES` is derived from the same table — the review statuses whose
`practice` flag is false — so the gate, the nav badge, the dashboard prompt and
the admission summary cannot drift apart about what is actually stuck.

`featureLock(key, pool)` returns null or a reason, and `lockedToggle()` renders
the disabled control that names it. `modeLock(mode, ctx)` does the same for the
practice grid and distinguishes **hard** (nothing to draw at all — the card does
not open, because opening it could only produce an error) from **soft** (the
mode runs exactly as it always did, it just cannot do the clever part yet — so
it is dimmed and stays clickable). Dimming is a warning; disabling is a
removal, and nothing here removes a mode somebody could already run.

## Installing, and where the bank lives

`manifest.webmanifest` carries the icon as an inline SVG `data:` URI, so no PNG
files are needed; the icon itself is the rail's tick mark. Its mark sits inside
the central 80% of the canvas, so the same file serves as `maskable`.

`DriveSync` keeps two separate ideas apart. `connected` means a live OAuth token
exists right now; `configured` means this browser's bank lives on Drive. The
second survives a reload and is true on a train — the first is false for the
first second after every reload while a silent token is fetched, and false
forever offline. `updateStorageBar()` used to ask only the first and, finding it
false, fall through to `FileStore.status()` → "Local only — not saving to a
file", with a Connect button, for somebody whose entire bank is on Drive. The
bar now belongs to Drive whenever Drive is the backend, with honest states for
reconnecting and for offline; `configured` is kept in step at connect,
disconnect, and the branch where a local folder wins.

## Working backwards from a date

`studyPlan()` is a pure function: it takes the pool, the case pool, the
attempts, the mastery target and a `YYYY-MM-DD` exam date, and returns the
dashboard card's entire content, verdict sentence included. It reads no globals,
so it can be tested against a hand-built bank rather than against a browser.

Each question falls in **exactly one** bucket — never attempted, attempted and
below target, or mastered with a review due before the day — so the three sum
to the backlog. A question that is both weak and due is one job; counting it
twice would inflate the target and report somebody as further behind than they
are.

Dates are `YYYY-MM-DD` local-date keys parsed by `dateKeyToLocal()`, never
`new Date(str)`: that parses a bare date as UTC midnight, which is 05:30 on the
day in India and 16:00 the day before in Los Angeles. `daysBetweenKeys()` rounds
its difference, because a clocks-change day is 23 or 25 hours long.

Today's progress and the seven-day pace both count **distinct questions**, not
attempts — the backlog's unit is the question, and a target reachable by
hammering one card would measure nothing.

## Ranking what is left by what it costs

`domainReadiness()` is the answer to a count being blind to the blueprint. Per
domain it splits the pool into `unseen` / `shaky` / `solid` — shaky being below
the mastery target, which is where a correct-but-guessed answer lands, since
`masteryOf()` docks 6 for each one — and ranks by

```
risk = share of the paper × (1 − solid ÷ total)
```

Weights are read as proportions rather than assumed to total 100, the same way
`weightedPick()` reads them. Two rules earn their place:

- **A domain with no questions has zero risk**, not maximum. `0 solid ÷ 0 total`
  reads as 0% ready, which would make an empty domain the most urgent thing in
  the plan and send somebody to a session that cannot be built. It is flagged
  as `empty` instead — a hole in the bank, fixed by importing, not by practice.
- **Ties break toward the unknown.** Two domains equally at risk are ordered by
  `unseen`, because material never seen is a bigger unknown than material seen
  and failed.

`studyPlan()` gains `phase` (coverage while anything is unseen, then
consolidate, then clear) and sizes the coverage window at 60% of the run-in, so
`unseenPerDay` leaves a real stretch for fixing rather than a scramble. Its
existing fields — the three buckets, `backlog`, `perDay` — are untouched, and a
regression test pins them.

## The readiness verdict

`readinessVerdict()` assembles what already existed — first-attempt accuracy,
coverage, `calibration()`, the mock trend, `domainReadiness()`'s top row — and
is the one function in the app where being wrong confidently would do real
harm, because somebody stops revising a week early. So its bias is silence:

- `null` on no evidence at all, `level: 'unknown'` with what is still needed on
  thin evidence — never a guess.
- `'ready'` requires **every** ingredient at once. Coverage alone cannot produce
  a pass claim, and neither can accuracy over a narrow slice: 92% on a fifth of
  the bank is `notyet`, with a sentence saying exactly that.
- `why[]` lists the evidence, in the same habit as `weaknessScore().why` and
  `masteryOf().parts`. A verdict that cannot be interrogated is a horoscope.
- It never emits a percentage chance of passing, and a test asserts no string it
  produces matches one.

Mocks are filtered on **marks actually available**, not on existing: a paper
whose questions have since been deleted returns zero from `markSession()` and
would otherwise read as a failure, holding somebody below `ready` on a record
that no longer refers to anything.

## Routing to the bulk tools

`bulkClassify()`, `bulkVerify()` and `bulkStatus()` predate all of this, driven
by `BankState.sel`. `bulkFrom(list, status)` is the route that was missing: it
sets `BankState` and calls `go('bank')`, the same pattern
`State.importStep = 'check'; go('import')` already used. The status to filter by
is read off the group — uniform when it shares one, blank for the mixed pile —
rather than threaded through four call sites. A group spanning both banks is
narrowed to the side being opened and reports what it left behind.

## The calendar file

WhatsApp and Web Push both need a server, and both would carry a phone number
and a study record off the machine. Notification Triggers, which would allow a
scheduled local notification, is not shipped by any browser — probed with
`Page.getAppManifest`-era capability checks in Chromium. A calendar file is the
one mechanism that works on every platform, iOS included, with no account and
no backend.

`buildStudyICS()` is kept pure and separate from the download so it can be
checked byte by byte. An `.ics` that is almost right imports as an empty
calendar with no error, so each rule has a test:

- **CRLF everywhere**, and no line over **75 octets** — counted in UTF-8 and
  split on code points, so an em dash in a course name is never cut in half.
- **Escaping** of `\`, `;`, `,` and newline, verified by unfolding back to the
  original text. (`'\;'` in a JS literal is just `;` — that bug was written
  twice here, once in the writer and once in the test that was meant to catch
  it.)
- **Floating local time** for the daily event — no `Z`, no `TZID` — which is
  what "remind me at seven" means, and needs no `VTIMEZONE` block.
- **`COUNT`, not `UNTIL`.** `UNTIL` must match `DTSTART`'s value type and
  UTC-ness; getting that subtly wrong is the classic way an `.ics` silently
  imports nothing.
- **Stable UIDs**, so re-exporting after changing the date updates the entries
  rather than duplicating them.
- **All-day `DTEND` is exclusive**, so a one-day marker ends the following day.

## The last mile, and the notebook

`lastMilePick()` contains no rng at all, unlike every other selection in the
app. A capped list has to be the worst N, and a shuffle would make it a sample
of them. Classes are tried in order — `wrong`, `flagged`, `lucky`, `never` — and
the first that applies is the question's single reason; within a class the sort
is wrongStreak, then mastery, then the oldest attempt, then qid, so the same
bank always yields the same list whatever order the index returned it in.

Questions with no attempts are excluded by `lastMileClass()` returning null for
them. `exportErrorNotebook()`'s "not since put right" scope calls that same
function, which is what guarantees the printed page and the sat session cannot
disagree about what is still broken.

The mode reuses the `redo` wiring: `Session.create()` builds a paper the
ordinary way — so marks, `s.marking` and the audit row are stamped exactly as
for every other session — and the questions are then replaced with the ordered
shortlist. Option order is still shuffled: knowing an answer by its position is
precisely the false confidence the session exists to find.

`PRINT_CSS` and `printableDoc()` are shared by both printable exports. Rules
only one of them needs go in `extraCss` rather than into `PRINT_CSS`, so adding
the notebook could not change a single byte of the question-bank export.

## Offline

`sw.js` is **network-first with the cache as fallback** — the opposite of the
usual advice, deliberately. This app is one document with no bundle and no
version manifest, so a cache-first worker would mean shipping a fix and nobody
seeing it. Network-first costs nothing online and returns exactly what was
missing offline.

The worker only ever touches same-origin `GET`s, so Drive sync and an external
OCR endpoint are untouched, and it caches only `200` responses — a cached 404
would pin a broken page in place. Registration is relative (`./sw.js`), never
absolute, because on GitHub Pages the app lives at `/reponame/`; it is skipped
on `file://` and where there is no worker support; and a missing `sw.js` is
caught and ignored, so `index.html` copied on its own behaves exactly as it did
before this existed. Settings can unregister it and empty the cache, because a
worker that needs devtools to undo is not one to ship.

## Handing a bank to somebody else

`shareableBank()` writes the **import** format, not the storage format, and
that is the whole design rather than a detail. A stored question keys its
answer by option id and carries a dozen fields naming rows in the sender's own
database — `canonicalUuid`, `dupOf`, `dismissedPairs`, `fingerprint`,
`courseId`. Written out as-is it reaches the reader with an answer the parser
cannot read and a set of dangling references, which is exactly what the first
version did: twelve questions arrived, none of them practisable.

Emitting `mcq-mastery-import/1` fixes both halves at once. The answer travels
as a **letter**, which is what `parseStructured()` reads. And the privacy
question becomes trivial, because the mapping is an **allowlist**: a field is
shared only if it is named in `shareableQuestion()`, so a personal field added
to the record later cannot leak by being forgotten in a denylist. The tests
assert against the *values* as well as the keys.

One thing does have to travel that the per-question allowlist deliberately
refuses: `answerVerified`. Keeping it out is right — it records who checked
what, in a database the reader does not have — but the *fact* that a person
checked has to reach them, because only practice-eligible questions are
exported and every one of those had its answer confirmed. Without it the trust
checkbox on **Source details** (off by default, correctly, since the ordinary
import is a PDF whose printed key nobody has verified) left the whole shared
bank unpractisable and needing an answer — which reads to the person importing
it exactly like an export that dropped the answer key. The file therefore
carries a single file-level `answersVerifiedBySender: true`, named apart from
the per-question field on purpose, and `sourceDialog()` preselects the
checkbox when — and only when — *every* file in the batch carries it, so one
shared bank cannot vouch for the PDF dropped alongside it. It preselects a
control the reader can clear; it never bypasses one.

Case-study questions travel inside their scenario rather than loose, so the
link between passage and questions cannot be lost, and a scenario with no
questions is omitted entirely.

What the reader gets: fresh uuids, Question IDs in their own numbering, their
own `courseId`, and **none** of the sender's stats, flags or review schedule.
Verification still requires the reader to tick "treat an answer printed in the
source as verified" — the app does not let a file assert its own answers are
correct, whoever sent it.

**`learningPoint` is deliberately absent from the allowlist**, and it was not
always. `learningPointBox()`'s own placeholder — *"What will you remember
next time?"* — names it as a personal, evolving reflection, not curated
content; it can also arrive from an import (a `learning point`/`note` column),
which makes typing over it the field doing its job, not a data-loss bug. The
conflict was with a feature built later: `shareableQuestion()` was carrying it
into the exported file as if it were teaching material, with the share
dialog's privacy copy never mentioning it. A private note about one question,
typed by a student who had imported that question from someone else's bank,
would have travelled straight back out to strangers. One line removes it from
the `carry` object; the dialog now names it explicitly, and the field itself
says in the UI that it stays private. Two other write paths for the same
field — `Session.answer()`/`Session.commit()`'s `meta.note`/`rec.note`
plumbing — were also removed: traced and confirmed unreachable, since the
runner's only caller never populates `meta.note`, matching the same
genuinely-unused bar the last code audit removed three functions against.

### The manifest, and why data/ had to change

`starterManifest()` caches one same-origin fetch of `data/starter-index.json`
and swallows every failure, so a deployment without one behaves as if the
feature does not exist. It carries three things: `files` (banks on offer),
`notices` (anything worth saying to a student), and `supportGroup` (one link
out, read from either `supportGroup` or the older `studyGroup` key so a
manifest drafted against the earlier name does not silently render nothing).
`datedVisible()` applies `from`/`until` as inclusive `YYYY-MM-DD` string
comparisons — no timezone gets a say in whether somebody can see their
material. `safeLinkOrNull()` drops anything that is not `http(s)`.

The support link renders in **Settings → About and licence**, not on the
dashboard. The distinction is what the link is *for*: a route to report a
problem with the app is needed rarely and looked for deliberately, so it
belongs where somebody goes when something is wrong, beside the licence and the
shortcuts. Notices are the opposite — timely, from the course, and worth
seeing without being sought — so they stay on the dashboard.

**The mechanism could never have worked as shipped.** `.gitignore` excluded
`data/`, so the file the app fetches was unpublishable, and git cannot
re-include a file whose parent *directory* is excluded. It is now `data/*` with
`!data/starter-index.json` and `!data/shared-*.json` — the two things meant to
be published are committable, and everything else under `data/` stays local,
which was the original intent.

## The first screen cannot be a wall

`go()` redirects every view to `onboarding` while `State.course` is null,
because every route below it assumes a course. `renderShell()` had the course
picker, the nav and the storage bar inside the same `if (State.course)` gate.
Together those made the first run a dead end for the one person most in need
of help: somebody who **already has a bank** and has just installed the app, or
reinstalled it, or lost their browser storage. They were told to add a course,
with no route to Drive, a folder or a backup — so the only way through was to
invent a throwaway course purely to unlock the sidebar.

Two changes, both small:

- The **storage bar moves outside the course gate**. Where the data lives is
  precisely what somebody with no course needs to see, and a configured Drive
  that has lost its token now says so there, with its Reconnect button.
- **`ROUTES.onboarding` carries the recovery routes itself** — Connect Google
  Drive, Restore from a backup, and Open my data folder where the browser has a
  picker. Putting them on the screen the person is already looking at beats
  unlocking a Settings page they cannot reach.

The nav stays behind the gate deliberately: those routes really do assume a
course, and a half-working Question Bank is worse than one that is not offered
yet.

### Data arriving from elsewhere has to bring its courses

`restoreFlow()` already re-read the course list after writing the stores.
`_applyRemote()` and `applyMergedBank()` did not — they called
`State.invalidate()`, which only marks a question cache dirty. So pulling a bank
from Drive onto an install with no course left `State.course` null, `go()` kept
redirecting to onboarding, and the person sat looking at "add your first
course" with their entire bank already in the database behind it. `adoptCourses()`
is now the shared step: re-read, prefer the remembered course, skip archived
ones, persist the choice, and `renderShell()` when the selection actually
changed.

## Losing the token, which on Safari is normal

The access token is in memory only and is never persisted — it is a bearer
credential for somebody's Drive, and a copy on disk would be a worse problem
than re-asking. On iOS Safari the page is reloaded often (the OS discards
backgrounded tabs), and the only refresh the app can perform is
`requestAccessToken({ prompt: '' })`, which needs a third-party cookie for
`accounts.google.com` that Safari blocks by default. So on that browser the
token is gone most of the time, by design at both ends. Four things follow, and
all four were wrong.

**A change made with no token still has to be remembered.** `touch()` used to
return early on `!connected`, so an edit while the token was dead set neither
`_pendingChange` nor the persisted `driveDirtySince` — and the next connect,
seeing no marker, pushed nothing. A session's practice could sit in the browser
while the bar said Drive was in sync. It now marks dirty whenever Drive is the
**configured** backend, connected or not, and only the push itself waits for a
connection. `configured` rather than `connected` is also what keeps a
local-folder user from accumulating a Drive marker they will never use.

**A 401 is not a network blip.** There was no 401 handling at all: the failure
became `problem = 'Last sync failed…'`, `connected` stayed true, and the dead
token kept its original expiry — so `_ensureToken()` went on short-circuiting on
"not expired yet" and every later call reused it. `_handleAuthFailure()` now
clears the token and its expiry so the next call has to ask again. It is applied
to `push()`, `pull()`, `_fetchModifiedTime()` and `_findExisting()`.

**`_findExisting()` returning `null` on a 401 was the dangerous one.** `connect()`
reads `null` as "there is no file yet" and creates one, so an expired token
could hand somebody a *second* Drive file and split their bank across the two.
"Not found" and "not allowed to look" now have different answers.

**A request that never answers must still end.** GIS settles `_requestToken()`
by invoking one of two callbacks; a blocked frame can invoke neither, and the
promise then never settled — with `push()` having already raised `_pushing`, so
every later push returned early while the bar showed "syncing…". There is now a
single settle gate with a 20s timeout, and `push()` takes the token *before*
raising its guard.

### And the state it leaves behind has to be actionable

`status()` returned "Drive: reconnecting…" indefinitely while the real reason
sat unread in `this.problem` — the check for it came after that branch — and
`updateStorageBar()` had no action for `drive-waiting` at all. So the browser
where reconnecting is the normal case got a label that never changed and
nothing to press. It now shows the reason when there is one, and carries a
**Reconnect** button. `retryQuietly()` also makes one silent attempt when the
tab becomes visible — at most one at a time, at most once a minute, and silent
on failure, because on Safari it will usually fail and a toast on every glance
at the app would be worse than the problem.

## Not re-asking a settled question

`init()`'s silent reconnect has always compared Drive's `modifiedTime` against
the `driveModifiedTime` stamp recorded at the last sync, and stayed quiet when
they match. `connect()` — the explicit button — never did: it ran the full
reconciliation dialog every time, whenever Drive held any questions at all.

On Chrome that is rarely noticed, because the silent token refresh usually
works and `connect()` is a once-ever action. On **Safari** it is the normal
path: the token does not survive the session, so a person reconnects by hand
every day, and met a dialog whose other routes are destructive every time.
That is precisely how somebody learns to tap through a dialog without reading
it — and the one occasion it matters is the one where it is not routine.

`driveSyncSettled()` is the decision, pure and asserted: same file, both
stamps present, stamps equal. Anything else — no record, a different file,
differing stamps, a stamp that could not be read — returns false and the full
dialog runs, because the cost of asking needlessly is a dialog and the cost of
skipping wrongly is a merge that never happened. Settled means "Drive has not
moved", not "the two are level", so a `driveDirtySince` left by an earlier
session is still pushed on the way through.

It also saves downloading the whole bank on every reconnect, since the
`modifiedTime` check is a metadata request and `pull()` no longer runs.

### Which action a dialog lands on

Merge is the only non-destructive answer, so it carries `kind: 'primary'`
everywhere the two copies meet, and "choose one side" never does. On a phone
that marking was being undone by the layout: `.modal-f` is a right-aligned row
that wraps, which put Cancel and the destructive escape hatch on the dominant
first line and dropped the primary onto a second line by itself. Under 880px
the actions now stack full width, `column-reverse` — every dialog in the app
puts its primary action last, so that lifts merge to the top and leaves Cancel
at the bottom, where a phone expects it.

## Fitting the rail on a phone

The rail is one column of fixed chrome wrapped around one scrolling `.nav`, so
anything spent above or below the nav is taken directly out of how many
destinations a person can see. It had grown to **387px** of chrome — wordmark
plus tagline, a labelled course picker, a storage bar stacking two full-width
buttons, and two footer rows — which on a phone with the browser's own URL bar
showing left the nav too short for its own contents. Settings, being last, was
the entry that fell off.

It is now **172px**, and the savings are all in things that were repeating
themselves:

- The tagline said "Controlled question bank" directly under a wordmark.
- The course picker's "COURSE" label sat above a control already reading
  "CISA — Certified Information…". It is still there for a screen reader, via
  `.sr-only`, and gone from the layout.
- The storage bar's two connect buttons share a row rather than stacking.
- The footer — theme, shortcuts, licence — is `display:none` under 880px. All
  three already live in Settings, and a keyboard-shortcuts dialog on a device
  with no keyboard was never worth 111px of the one screen that had none to
  spare. Nothing was removed from desktop.

Two further tiers exist so the smallest screens are not left broken: under
630px tall the rows drop from a 44px touch target to 40px, and under 580px the
wordmark goes too. Above 630px nothing is compressed at all, because it does
not need to be.

## Every disconnected state has to be pressable

`FileStore.status()` has two disconnected keys, and only one of them used to be
actionable. `local` — a browser with `showDirectoryPicker` — got Connect
folder and Connect Drive. `manual` — **iOS, and Firefox everywhere** — got the
label "Local only" and nothing to press.

That is backwards. A browser with no folder picker is a browser whose bank has
*no file behind it at all*, so it is the one that most needs a route out, and
Drive is available there: it needs nothing but the network. The `manual` case
now says why the folder option is missing ("Folders need Chrome or Edge") and
offers Connect Google Drive. Both keys' labels were changed from "Local only"
to **"In this browser only"**, which is the fact rather than a category name.

## The promise nobody asks for

`Durability` wraps `navigator.storage`, and the reason it exists is that
IndexedDB is **best-effort storage by default**. A browser may evict it under
pressure, and Safari clears script-writable storage after seven days without a
visit. For a bank behind a folder or Drive that is a non-event — boot calls
`loadFromDisk()` and everything returns. For a bank that is only in the
browser, it is total loss with nothing deleted by anybody.

`persist()` is the request that changes it. Three things shape when it is
called:

- **Only when there is something to protect.** `ensureDurableStorage()` returns
  early unless `browserIsOnlyCopy()` and `DB.count('questions')` are both true
  of the situation. Asking is free in Chrome, which answers silently on its own
  heuristics, but Firefox shows a permission prompt — and a prompt in front of
  somebody with an empty bank is a prompt that teaches them to dismiss prompts.
- **Never before the first paint.** The boot call is a 1200ms `setTimeout` after
  `go('dashboard')`, for the same reason. It also runs at the end of
  `admitBatch()`, because that is the moment a bank comes into existence and
  waiting for the next visit assumes there is one.
- **Idempotent.** It re-reads state rather than trusting a flag, and returns
  early once granted, so it can be called from anywhere.

`durabilityAdvice()` is the pure half, so the wording is assertable. It returns
`null` in the two cases where saying anything is noise — an empty bank, and a
bank with a file behind it — which is most people, most of the time. When it
does speak it names fixes in order of how well they work: a folder or Drive
first, then installing the app (dropped when already installed, and dropped
entirely when the browser has no Storage API, where it would not help),
then backups. The granted case is deliberately not oversold: persistence stops
eviction to free space and nothing else, and the note says so rather than
letting somebody read it as a backup.

## Handing over the app itself

`exportSelfContainedCopy()` fetches the app's own files over the same origin it
is running from and zips them. It has no build step and no file list baked in
anywhere else: `LOCAL_BUNDLE` is the single declaration of what a copy is, and
each entry carries a `required` flag. Only `index.html` is required — every
other file is a graceful degradation, so a deployment missing `serve.ps1`
produces a working copy rather than an error, and the names that could not be
fetched are recorded in the note instead of silently vanishing.

It re-uses `zipFiles()`, the writer the backups already use, rather than a
second archive path. That is why the test asserts a round trip through
`unzip()` and not just the entry list: a name that survives the central
directory but inflates to nothing is a file that opens to a blank window, with
no error raised anywhere.

`startHereText()` is a pure function of `{ version, when, from, missing }` — no
DOM, no fetch — which is what lets its wording be asserted. It is deliberately
plain text: the one file a person reads before running anything they downloaded
should not itself need the thing they have not run yet.

### Why the export can refuse

The interesting part of this feature is the guard, because the failure it
prevents is silent. A local copy runs at a different origin, and origin is what
partitions IndexedDB — so a copy taken by somebody whose bank exists only in
the browser opens empty. Nothing is lost and nothing errors; it simply is not
there, and it looks exactly like a broken export.

`localCopyRisk()` returns non-null only when every escape route is absent:

```js
if (!questions)                 return null;   // nothing to strand
if (FileStore.connected)        return null;   // the bank is a file already
if (DriveSync.configured)       return null;   // ditto, on Drive
if (backup newer than 7 days)   return null;   // restorable into the copy
```

It reads `DriveSync.configured` rather than `DriveSync.connected` for the same
reason `updateStorageBar()` does: a lapsed token is not a lost bank, and a
person whose whole bank is on Drive should not be told they have no copy of it
because they have not signed in yet today. The week is a judgement — a backup
older than that is not cover for a bank being practised on daily — and the
modal states the actual date so the person can disagree with it.

When it fires, the export is refused and replaced by the two things that fix
it, as actions rather than advice: *Connect a folder* runs `connectFlow()` and
*Back up now* goes to Backup. Both make the bank a file, which is the whole
resolution — the copy then reads the same file, and the second origin's empty
database stops mattering.

## Sections, and changing your mind

`sectionsFor()` returns sections only for a mock that has both a standalone run
and a case-study block; every other paper is one undifferentiated run and
`session.sections` is simply absent. Budgets come from
`defaultSectionBudgets()`, proportional to the **marks** each section carries —
identical to splitting by question count when the sections are weighted the
same — and an explicit case-study budget takes its remainder from the other, so
the two always sum to the paper's limit. It takes a courseId rather than
reading `State.course`: it is arithmetic over a paper, and nothing about it
should depend on which course happens to be selected when it runs.

`carryAnswerChanges(prev, rec)` moves the change history onto each successive
response, keeping `firstOptionId` — the first answer ever given to that question
in that session — and appending to `changes` only when the selection actually
differs. `answerChangeReport()` classifies on **first against final**, not on
each hop, because the hops say nothing about instinct and nobody remembers
them. A change that lands back where it started is counted as a change and
appears in none of the three outcomes, because it changed nothing.

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

The queue itself is split into "waiting on you" and "already in practice",
because `REVIEW_STATUSES` and `BLOCKING_STATUSES` are deliberately different
sets and the screen was reporting both without saying so: the step tab counted
4 blocked while the list showed 256 worth a look. Both numbers are true, and
they are now stated together at the top of the queue. The old catch-all
"Other" bucket straddled that line (`parsing`/`draft` block practice,
`needs_content` does not) and is now two, named for what is actually wrong.

The split reads `isStuck()`, not `isBlocked()`. The difference matters:
`isBlocked` reads the status alone, and the status alone is not the gate.
`candidateToQuestion()` files an imported candidate as `needs_class` on a
missing domain without ever looking at `answerVerified`, so "unclassified" and
"answer nobody confirmed" arrive on one record and only the first reaches the
status — `isBlocked` says no, `isPracticeEligible` refuses to ask it. Three
screens then counted one bank three ways: a source register 17 short of
practice-ready, a step badge of 4, and a queue filing the other 13 under
"already in practice". Every "waiting on you" count now reads `isStuck`
(`isPracticeEligible`, less the retired statuses), and rows it catches inside
an optional section say what practice is still waiting for, in `entryBlockers`'
own words. The one state with no screen of its own — not practisable and not
in `REVIEW_STATUSES` — is an `integrityChecks()` line rather than something
you can only find by subtracting one count from another.

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
(`JSON_ALIASES` / `jsonPick`), and the reference panel on Add Questions
(`showImportReference()`) is rendered from it. The app therefore cannot
advertise a column it does not read, or read one it does not advertise. That
panel groups the fields for reading (`IMPORT_FIELD_GROUPS` — presentation
only, and anything it fails to name still appears under "Anything else"), and
splits by file format, because the three formats share a field table but not a
syntax. Its document tab goes one step further: every line label it shows is
tested against the `RX` rule `parseText()` matches it with before it is
rendered, so a label the parser would not read cannot appear on the screen
that promises it will. The case fields (`caseRef`, `caseTitle`,
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
a per-browser override, for a fork running from a different origin. That
override lives in `localStorage` (`mcq.driveClientId`), deliberately not in
the `settings` store: `settings` is part of the bank that syncs through Drive
and the local file, so an ID typed once on one machine used to ride the sync
onto every other device signed into the same account — each of which then
reported it was "using a custom Google connection" nobody there had chosen.
`migrateDriveClientIdOutOfSync()` lifts any such row out of the store at boot,
and an override that merely repeats `DEFAULT_DRIVE_CLIENT_ID` counts as no
override at all. Settings → "Where your data lives" has the one-time Cloud
Console walkthrough, shown only when no client ID — default or override — is
set.

Two status surfaces read the same state and used to disagree about it. The
"last synced" stamp now lives in `fsmeta` (`driveLastSyncedAt`, written by
`_markInSync()` on a push, on adopting the remote copy, and whenever a boot
check finds the two already level) rather than in memory only — held in memory
it was null after every reload, so a bank that had been on Drive for weeks was
described as awaiting its first sync while the sidebar said "syncing…" with
nothing pending. And Settings' "Where your data lives" keys off `configured`
rather than `connected`, the distinction `updateStorageBar()` already drew: on
Safari, which cannot carry a Google token across a reload, keying it to a live
token reported "Browser only" and offered a fresh connection for a bank that
was sitting in Drive.

The connection is meant to outlive a reload, and everything except the Google
token does: the file id, the sync stamps and the dirty marker are all in
`fsmeta`. A token cannot be, and on Safari cannot even be renewed silently, so
`tryResume()` keeps trying for one — scheduled with a backoff from 30s to 10
minutes, and immediately when the tab returns to the front or the network comes
back. Each success runs `_catchUpWithDrive()` (the same reconciliation boot
does) and flushes anything `driveDirtySince` recorded while signed out. Before
this, a failed silent renewal at boot started no timer and registered no
listener: the browser saved locally and pushed nothing until somebody noticed
the sidebar and tapped Reconnect.

The auto-retry only ever runs for a bank that already lives on Drive
(`configured`), and every attempt is `_requestToken(true)` — silent, no popup.
A browser-only bank schedules nothing and is asked nothing; it gets the banner
below instead.

`browserOnlyRisk()` decides the one warning that cannot live in Settings, and
`#riskbar` renders it under the sticky band in every view. It used to be told
only by the Settings card and the rail's storage bar, and on a phone the rail
is behind a hamburger — so the device least likely to have a folder was the
device least likely to hear about it. It stays a warning rather than a wall:
"Not now" hides it for the session, "Stop reminding me" records the question
count in `browserOnlyAckedCount` and stays quiet until the bank grows
`RISK_ACK_GROWTH` past it — deliberately working in one browser and discarding
it afterwards is a legitimate thing to do.

`buildPayload()` re-reads only the stores `FileStore.touch()` marked dirty
since the last build, and that marking is deliberately independent of which
backend is connected — Drive calls `buildPayload()` with no folder in sight.
While it sat behind `if (!this.connected) return`, a Drive-only bank (every
iPhone: no folder picker exists there) built its payload once and then pushed
that same first snapshot for the rest of the page's life. Every sync reported
success and none of them carried anything answered since; only a reload, which
drops `_cache`, let new work through, which is why it presented as intermittent
rather than broken. The journal, the snapshot decision and the `dirty` flag stay
behind the connected check, because those really are the local file's business.

The uploaded bytes are gzipped where the browser can (`CompressionStream`), and
a bank file is read as "gzip or JSON", decided by the two bytes gzip always
starts with rather than by anything recorded. Question text and base64 images
compress by roughly an order of magnitude, which on a phone is the difference
between a sync that finishes and one that drops; a browser without compression
uploads exactly what it did before, and either shape stays readable for ever.

Deleting a course writes a course-level tombstone (`COURSE:<id>` in the same
store its questions use, so an older build sees a tombstone with no uuid and
ignores it). The merge drops the course row and every store filed under it —
questions, answers, sessions, notes, sources, batches, presets, case studies —
on both sides. Tombstoning only the questions left the rest to be pushed back by
whichever device had not caught up, so a deleted course reappeared everywhere,
empty, and deleting it again restarted the loop.

`applyMergedBank` also recomputes mastery for the questions a merge touched,
from the answers both sides now hold: the score is derived from the whole
history but stored on the question, so the row that wins a merge otherwise
carries a number calculated on half of it. Written without a stamp — arithmetic
over existing facts is not an edit, and stamping it would hand that device every
future merge.

A push is one whole-file `PATCH`, so on a bank of any size it is a long
request and a phone's wandering signal ends it. `push()` retries the network
class of failure once, 2.5s later, reusing the body it already serialised —
never an auth or status failure, which retrying cannot fix — and
`describeSyncFailure()` turns what is left into words. A failed `fetch()`
throws the browser's own text ("Load failed" on WebKit, "Failed to fetch" on
Chrome), which appeared verbatim in the sidebar and read like an app fault
rather than a dropped upload; the payload size is named alongside it, since a
multi-megabyte bank going up in one request is usually the reason.

`unsyncedRisk()` fills the other half of the same strip. Drive being the
backend does not mean this browser is level with it: a Google sign-in expires,
a backgrounded tab is frozen mid-upload, a phone leaves signal. Nothing is lost
— `driveDirtySince` survives and the next sync sends it — but until then this
browser holds the newer copy, and opening the bank elsewhere hands you the
older one with nothing saying so. Past a two-minute grace (below that it is
just the debounce) the banner says it, and offers one button that signs in if
that is what is missing and pushes either way.

What no amount of this can fix, because there is no server: a browser that has
never connected anything is invisible to every other one. Work done there is
not lost — connecting Drive later reconciles it, offering a merge that keeps
both sides — but until that browser is opened again, no other device can know
the work exists. That is the cost of the local-first design, not a defect in
the sync.

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
