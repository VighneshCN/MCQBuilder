# MCQ Mastery

A local-first MCQ practice and revision app. One universal question bank per
course, permanent Question IDs, full source traceability, duplicate detection,
and attempt history that survives question edits.

Everything runs in your browser. No backend, no cloud database, no API keys, no
network calls at runtime. Your question bank never leaves your machine.

Ships with two courses configured — **CISA** and **DISA AT** — and no questions.
You import your own.

---

## How it works, start to finish

The nine sections below cover everything in detail. This is the shape of it.

**1. Set up a course.** A course is one exam — CISA, CA Final Audit, whatever
you are sitting. You give it chapters (the app calls them domains) and the
weight each one carries in the real paper. That weighting is what later makes a
mock resemble the exam rather than resemble your bank.

**2. Get questions in.** Four ways in: drop a file (Word, Excel, CSV, JSON,
plain text, text-based PDF), photograph a page, paste raw text, or type one by
hand. The app reads them, shows you everything it found, and **writes nothing
until you confirm**.

**3. It sorts what it read into three piles.**

- **Ready.** It has a question, options, a correct answer, and that answer is
  confirmed. Straight into practice.
- **Waiting on you.** No answer key was found, two sources disagree about the
  answer, or it looks like something already in your bank. These **cannot be
  practised** until you decide — drilling yourself on a wrong answer key is
  worse than not drilling at all.
- **In practice, but not fully filled in.** No domain, or wording the parser
  was not fully confident it read. These **practise normally**. They simply
  cannot yet do the things that need the missing information.

That third pile is the whole design: see
[What a question actually needs](#what-a-question-actually-needs) for exactly
what is required and what each optional field switches on.

**4. Practise.** Nine modes, plus a tenth once you have a case study. Five work
from the moment you have questions: Learning, Domain drill, Mixed revision,
Timed mock exam and Custom practice. Four need some history behind them before
they can say anything — Weak topics, Incorrect & guessed, Last-mile revision and
Spaced repetition — and until then each is dimmed and says on its own card what
will wake it, rather than showing you a zero.

**5. Every answer records four things.** Whether you got it right, how long you
took, how you got there (knew it, reasoned it out, unsure between two, guessed),
and — when you got it wrong — why. That last one is a list you pick from:
misread it, missed a FIRST/BEST/MOST qualifier, confused two concepts, rushed.

The first time you answer a question it also asks how hard it was, in the same
dialog. Once graded, it never asks again.

**6. Every answer also schedules when that question comes back.** Wrong →
tomorrow. Guessed right → tomorrow too, because a lucky guess is not knowledge.
Unsure → 3 days. Reasoned it out → 7. Knew it → 14, then 30, 60, 90 on repeat
successes. Spaced repetition is not the mode that creates this schedule; it is
the mode that practises whatever has fallen due.

**7. What comes back to you.** Marks and whether that would have been a pass.
Where your time went, and which questions cost you the clock. Whether you knew
what you thought you knew. Which wrong option keeps catching you, and on which
questions. What you changed your mind about, and what changing it cost.

**8. Getting to the date.** Set an exam date and the dashboard works backwards
from what your bank still owes you to a questions-a-day target — and, using
your exam weights, says which chapter that effort should go into. Export a
calendar file and your own phone reminds you daily. In the last week, Last-mile
revision hands you the worst of what is still broken, and the error notebook
prints everything you have got wrong so you can revise from paper.

**9. Where your data lives.** One home at a time — a folder on your disk **or**
your Google Drive, never both at once. The browser database is a working copy,
rebuilt from that home every time you open the app.

### The one thing that unlocks the most

**Filing questions under domains.** Without it, domain drill cannot focus, a
mock cannot follow your exam weights, and accuracy-by-domain has nothing to
split. With it, all three switch on. You can do it whenever you like — in bulk
from the Question Bank, or as one field at import for a whole file.

Two smaller ones: **difficulty** unlocks papers built to a difficulty mix (grade
them as you practise, one question at a time, and it switches on the moment the
first one is graded), and **explanations** are what you are shown at reveal.

---

## 1. Running it

### Windows, locally

Double-click **`Start MCQ Mastery.bat`**. A console window opens and your
browser launches with the app loaded. Keep the console open while you work;
closing it stops the server. Your data is unaffected — it lives in the browser
and in your data folder, not in the server.

It needs nothing installed. It uses PowerShell, which ships with Windows, and
binds to the loopback address only, so nothing is exposed to your network.

### macOS, Linux, or if you prefer a terminal

```bash
npx --yes serve .              # Node
python3 -m http.server 8080    # Python
```

### From GitHub Pages

If you have published this repo (see `GITHUB-PAGES.md`), the app runs from its
URL with no setup. Read section 2 first — it matters more than it looks.

If you would rather not depend on that URL at all, the app will hand you a copy
of itself to keep: see **Keeping your own copy of the app** in section 5.

### Why not just double-click index.html?

Browsers block IndexedDB for pages opened from disk over `file://`, and that is
where the working copy of your bank lives. This is about the page's origin, not
about file access, so no browser API works around it. The `.bat` launcher exists
to make this a double-click anyway.

## 2. Where your data lives — read this first

The app can keep your entire bank in **a single JSON file in a folder you
choose**, instead of trapping it inside one browser profile. Go to
**Settings → Where your data lives → Connect a folder**.

Once connected, that file is the real home of your data. The browser database
becomes a working copy, rebuilt from the file each time you open the app. Back
the file up, sync it, or copy it to another machine and open it there.

**Two things to get right:**

**Point it at a folder outside this repository.** Something like `D:\MCQData`.
If you connect the repo folder, the app writes your bank into it and the next
`git add .` pushes your entire question bank — including any copyrighted source
material in it — to GitHub. The included `.gitignore` guards against this, but
a separate folder is the real fix.

**Browser storage is per-origin.** Data saved at `localhost:8080` and data saved
at `yourname.github.io` are *completely separate databases*. Practise on one and
the other will not see it. Connecting a data folder solves this — the file
becomes the shared truth both can read. Without a connected folder, pick one
address and stay on it.

Requires Chrome, Edge, or another Chromium browser. Firefox and Safari have no
folder API; there the app keeps everything in the browser database, and regular
backups from **Backup & Restore** are your safety net.

### Opening it for the first time when you already have a bank

An installed app — Home Screen on iOS, Install on Chrome — gets **its own
storage, separate from the browser you installed it from**. That is the
platform's doing, not a setting. So the installed copy always starts empty,
even when the same app in the browser is full of your work.

The first screen therefore offers two things beside *Add a course*: **Connect
Google Drive** and **Restore from a backup** (plus *Open my data folder* where
the browser supports it). Use one of those and your courses come back with your
questions. **You never need to create a course first** — an earlier version made
you invent a throwaway one just to reach Settings, which was wrong.

### Google Drive on an iPhone or iPad

**Drive asks you to reconnect roughly once per session on Safari, and there is
nothing the app can do about it.** Two things Apple does combine:

- iOS discards a browser tab that has been in the background — lock the phone,
  or switch apps for a minute — and reloads it when you come back. The Google
  token lives only in memory, deliberately: it is a key to your Drive, and
  keeping a copy of it on disk would be worse than asking again.
- Getting a token back without asking you requires a cookie for
  `accounts.google.com`, which Safari blocks by default as tracking protection.
  So the silent path that works on Chrome cannot work here. This is Google's
  own documented behaviour, not a fault in the app.

**Nothing is lost in between, and this is the part worth understanding.** Your
bank is in the browser the whole time, and everything you do while Drive is
disconnected is recorded as still-to-send. The moment you reconnect, it goes
up. Practise for an hour with the sidebar saying *tap to reconnect* and not one
answer is dropped — it simply arrives on Drive when you next connect.

The sidebar carries a **Reconnect** button whenever this happens, from whatever
screen you are on. One tap, and if nothing has changed on Drive meanwhile you
are not asked anything further.

Two things reduce it, neither completely: **add the app to your Home Screen**
(Share → *Add to Home Screen*), which makes iOS less eager to discard it, and
keep the tab in the foreground while you practise. On Chrome, Edge and Android
this rarely comes up at all.

### Whether your browser has promised to keep it

The browser database is the app's working copy. For anyone with a folder or
Drive connected that is all it is — a cache in front of a file, and if the
browser ever cleared it, the app would simply reload everything from the file
on the next open.

For anyone **without** either, it is the only copy — and by default browsers
make no promise about it at all. They are allowed to clear it to free space,
and on some phones they clear it after a few weeks without the app being
opened. This is the one way to lose a bank that does not involve anybody
deleting anything.

So when you have questions and no file behind them, the app asks your browser
to keep them — `navigator.storage.persist()`, the standard way to ask. Chrome
and Edge answer silently on their own criteria, and **an installed app is the
case they reliably say yes to**; Firefox asks you; some browsers cannot answer
at all. Settings → *Where your data lives* shows which answer you got, with a
button to ask again.

It is worth knowing what that promise does and does not cover. It stops the
browser clearing your data **to make room**. It does not survive you clearing
your browsing data, or uninstalling the browser. Connecting a folder is still
the thing that makes your bank genuinely yours — this is the safety net for
before you do.

### What appears in your data folder

| File | What it is |
|---|---|
| `mcq-mastery-data.json` | Your bank. This is the file that matters. |
| `mcq-mastery-journal.jsonl` | Answers since the last full write. Emptied each time the bank is rewritten. |
| `mcq-mastery-data.previous.json` | The prior verified version, kept for rollback. |
| `mcq-mastery-safety-backup-*.zip` | Written automatically before a deletion or a replace-restore. |

If you copy your bank elsewhere, take `mcq-mastery-data.json`. The others are
derived and disposable.

### How your data is protected

- Every save is **read back and verified** — it must parse and hold exactly the
  expected number of questions — before it is trusted.
- A save that would **remove more than half your bank** without you asking for
  it is refused outright, and the app goes read-only rather than guessing.
- If the data file is **deleted, moved, or changed by something else**, the app
  notices — before each write, every 30 seconds, and whenever you return to the
  tab — stops writing, and asks what you want to do. It will not silently
  recreate a file you deleted, or overwrite a version written elsewhere.
- **Deleting a course's questions or doing a replace-restore takes a verified
  backup first**, automatically. If the backup cannot be made, the deletion is
  abandoned.

## 3. Getting questions in

**Add Questions** accepts `.docx`, `.csv`, `.xlsx`, `.json`, `.txt`, text-based
`.pdf`, and images. Drag files onto the drop zone, or paste a screenshot with
Ctrl+V.

Nothing is written until you confirm. Every question that enters the parser is
accounted for on the reconciliation screen — imported, held for review, or
rejected. Nothing is silently dropped or guessed.

### What a question actually needs

Three things, and only three:

| Needed to practise a question | Why |
|---|---|
| The question text | Obvious |
| At least two options, one marked correct | Otherwise there is nothing to mark |
| That answer confirmed | The app will not drill you on an answer key nobody has checked. One tick at import — *"Treat an answer printed in the source as verified"* — does this for a whole file |

**Everything else is optional and unlocks something.** Nothing else holds a
question out of practice:

| Not filled in | What stays switched off until you do |
|---|---|
| Domain | Domain drill focuses on everything instead; a weighted mock cannot follow the blueprint; accuracy by domain has nothing to split |
| Difficulty | Papers built to a difficulty mix |
| Explanation | Nothing is shown to you at reveal beyond the right answer |
| Per-option reasons | The "why the option you picked was wrong" box |
| Marks | Every question is worth one |
| Case study link | It stays in the standalone bank |

You will see this in the app rather than have to remember it: a control that
cannot do anything yet is **shown, disabled, saying what it runs on** — not
hidden, and never offered and then refused. Tick nothing, import a plain file
of questions and answers, and you can practise immediately; fill things in
later and features switch themselves on. Grading a single question's difficulty
is enough to unlock difficulty-based papers.

### Writing one question yourself

You do not need a file. **Write a question by hand** — the first entry under
"Other ways in", and the **New question** button on the Question Bank — opens a
form for exactly one question: the stem, as many options as your course expects,
and which one is right.

It tells you as you type whether what you have written will actually reach
practice, and when it will not, the specific things still to do. It checks the
bank as you type and warns you, with the Question ID and a side-by-side
comparison, if you are retyping something already there. **Save & add another**
keeps the domain, topic, difficulty and source and clears only the question, so
typing twenty questions from one chapter means setting the domain once.

Nothing is written, and no Question ID is spent, until you press Save.

### If the app cannot read your column headings

A spreadsheet whose headings it recognises imports straight away. One whose
headings it does not — your own export, someone else's template, a file in
another language — **asks** rather than guessing. Every column in the file is
listed with the first few values actually in it, next to a dropdown naming what
it means; anything it did recognise is filled in already. There is also a
checkbox for "this file has no header row at all", which reads every row
positionally.

**Start from a template** on the same screen hands you a file already in the
right shape. Two kinds — questions and case studies — each in four formats:

| | What it is for |
| --- | --- |
| `.csv` | One row per question. Opens anywhere. |
| `.xlsx` | The same sheet as a real workbook, straight into Excel with no import dialog. |
| `.json` | The same fields as structured data, for anything generating questions programmatically. |
| `.docx` | A sheet you fill in and save as PDF — see *When a PDF will not read* below. |

The `.csv` and the `.xlsx` are the same rows written twice, so they import
identically; pick whichever you would rather edit in. Hovering a format says
what it is for. Next to them, **"What should my file look like?"** opens a
worked example of a file that imports cleanly — a tab each for spreadsheets,
documents and JSON — followed by every accepted heading and key, grouped so
the three that are actually required are not lost among the thirty that are
not, and searchable if you already have a column and want to know whether it
is read. All of it is generated from the parser's own table, so it cannot
advertise a column the app then ignores.

### Protected PDFs

A PDF that opens in your reader without asking for a password imports here the
same way, even when it is marked as protected. Study material, exam papers and
bank statements are routinely encrypted against *copying and printing* while
carrying an empty user password — nothing is locked to you, and the app now
derives the key and reads them. Revisions 2 to 6 are supported, RC4 and AES
alike.

A PDF that genuinely needs a password to open is refused, and says so, which is
a different sentence from the one above — the app can tell the two apart.

### When a PDF will not read

The app decodes PDF text itself, with no external library. That covers most
documents, but not every one: a PDF built from compressed object streams, or
one whose fonts carry no usable character map, has no text this app can reach —
and a scanned PDF has no text at all. It says so rather than importing nonsense.

The way round it is **Question sheet for PDF (.docx)** and **Case study sheet
for PDF (.docx)** under *Start from a template*. Copy the text out of the
original, paste it into the sheet, and save the sheet as PDF. Because the layout
is one the parser is built around, what comes back is exactly what you put in:

```
MCQ MASTERY — QUESTION SHEET
Domain: D1
Module: Module 1

Q1. An IS auditor finds a control weakness. What should the auditor do FIRST?
A) Report it to the audit committee
B) Corroborate the finding with additional evidence
Answer: B
Explanation: Findings are corroborated before they are reported.
Difficulty: medium
```

`Domain`, `Module` and `Topic` under the banner apply to every question in the
sheet; repeating any of them inside a question block overrides it there. The
instruction block above the banner is ignored on import, so it can stay.

The case-study sheet adds three markers, and is the only way to bring a scenario
in from a document rather than a spreadsheet:

```
CASE: CS-1
TITLE: Kaveri Textiles — ERP post-implementation
DOMAIN: D5
SCENARIO:
The whole passage, across as many paragraphs as it takes.
END SCENARIO

Q1. Which finding should the auditor report as the MOST significant?
...
```

`END SCENARIO` is not decoration. A passage is ordinary prose, and without a
closing marker there is nothing to say where it stops and the first question
starts. Questions under one `CASE:` reference become one case study, numbered in
the order they appear. Neither marker is read as structure in an ordinary
document — a line like `Case: Salomon v Salomon` stays text unless the sheet
banner is present, or the document really does open and close a scenario.

Both sheets import as `.docx` directly too, if you would rather skip the PDF
step.

### Two settings that matter on import

**"Treat an answer printed in the source as verified"** — tick this when your
document prints its own answer key, or every question will need its answer
confirmed by hand.

**"Official domain for this batch"** — set this only when the whole file belongs
to one domain. Leave it empty for a file that carries its own per-question
domains, or the batch setting will override them.

### Questions generated with Gemini, NotebookLM or ChatGPT

Fastest path if you generate MCQs from your own notes. Two options, neither
needing cleanup:

**Ask for JSON.** Paste this at the end of your prompt:

```
Output ONLY valid JSON in exactly this shape, with no commentary and no
markdown code fences:

{"schema":"mcq-mastery-import/1","questions":[
  {"stem":"...","options":[{"letter":"A","text":"..."},{"letter":"B","text":"..."},
   {"letter":"C","text":"..."},{"letter":"D","text":"..."}],
   "answer":"B","explanation":"...","topic":"...","difficulty":"medium"}
]}
```

Save the reply as `.json` and drop it in. Everything except `stem` and `options`
is optional.

**Or ignore the format entirely.** Use **Paste raw text** and paste whatever the
model gave you. The parser handles what these tools naturally produce:

```
1. Which control is preventive?
A. Log review
B. Access authorisation
Answer: B
Explanation: Authorisation stops the event before it happens.
```

It also copes with `The correct answer is: B.`, answers stated in the same
paragraph as the explanation, options split across lines, and answer keys
(`1-B, 2-C, 3-A`) at the end of a document.

**Start from a template** in Add Questions gives you a worked example of every
supported field. The app generates these itself; there are no template files to
find. The two `.docx` sheets there are the same thing for documents rather than
spreadsheets — see *When a PDF will not read* above.

### Shipping question sets with the app

Optional. Put a JSON file in a `data/` folder next to `index.html` and list it in
`data/starter-index.json`:

```json
{
  "schema": "mcq-mastery-catalogue/1",
  "files": [
    { "file": "data/my-questions.json", "course": "CISA",
      "label": "My question set", "questions": 500,
      "note": "Where these came from and how they are tagged.",
      "defaultDomainId": null }
  ]
}
```

A card then appears in Add Questions. The app checks the file really exists
before offering it, and takes the real count from the file at import. No `data/`
folder means no cards, which is the correct behaviour for a published repo —
**do not commit question files you do not own the right to redistribute.**

## 4. Practising

Nine modes: Learning, Domain drill, Weak topics, Incorrect & guessed,
**Last-mile revision**, Mixed revision, Timed mock exam, Spaced repetition,
Custom practice. A tenth, **Case study questions**, appears once you have a
case study — see section 5.

After each answer you record how you got there — knew it, reasoned it out,
unsure between two, guessed. This matters more than it looks: a correct guess is
tracked separately from a correct answer you knew, so **Weak topics** and
**Incorrect & guessed** surface what you are actually shaky on rather than just
what you got wrong.

**Every answer, in every mode, schedules when that question comes back.** Spaced
Repetition is not the mode that creates the schedule; it is the mode that
practises whatever has come due. Wrong resets to 1 day; guessed 1; unsure 3;
reasoned 7; knew it 14, then 30, 60, 90 on repeat successes. A timed mock asks
for no confidence, so a correct answer there is held to a short interval rather
than treated as knowing it.

Mock exams draw questions weighted to the course blueprint, and can carry a
case-study section — see section 5.

### How many a day, and how many days

Set an exam date in Settings → **Practice and mock** — or from the dashboard —
and the dashboard stops describing the past and starts working backwards from
the date.

It counts what your bank still owes you, and each question owes exactly one
thing: it has **never been attempted**, or it has been attempted and is **still
below your mastery target**, or it is mastered but its **review falls due before
the day**. Nothing is counted twice, so the three add up to the number of
questions you have left, and dividing that by the days remaining — today
included — is the number you have to get through daily.

Today's progress is counted in *questions*, not attempts: twenty goes at the
same question is one off the list. Underneath, a reality check from the last
seven days — *"At your recent 38 a day you would reach 950 of the 1,240"* —
averaged over all seven days rather than only the ones you practised, because
skipping four days a week is exactly the thing worth seeing.

None of this appears until you set a date. There is no card, no countdown and
no nag beyond a single line offering to set one.

#### It also tells you *which* questions

A daily count on its own is blind to your syllabus. You could hit it for three
weeks entirely inside one chapter and reach the exam with a chapter worth a
quarter of the paper barely touched — being told "on track" every morning.

So the plan reads your exam weights. For each domain it works out how much of
it is **solid**, and ranks what is left by what the shortfall actually costs:

> a domain worth 26% that is 40% ready is a bigger problem than one worth 12%
> that is 20% ready

The card names that domain and offers one click to practise it, with the filter
already set. Underneath, **Readiness by domain** shows every chapter, its share
of the paper, and how much of it is solid — folded away until you want it.

If your bank has *no* questions at all for a domain, that is said separately.
It is a gap in the bank rather than in your revision, and no amount of practice
closes it.

#### Two phases, because that is how revision actually goes

While anything is unseen you are in **coverage**: the card says how much of
today's number should be new ground, sized so the whole bank is seen once by
about 60% of the way to the exam. That leaves a real stretch at the end rather
than a scramble.

Once everything has been seen once it switches to **consolidation** — what is
left is the shaky ones and the reviews falling due.

#### "Solid" is stricter than "I got it right"

A question counts as solid only at or above your mastery target, and mastery
docks points for a correct answer you marked as a **guess**. So a question you
guessed right stays on the list, and the card says so rather than leaving you
to work it out.

### Are you ready?

One card, one sentence, and it is deliberately hard to please:

> **On this evidence you would pass. The risk is Protection of Information
> Assets.**

To say that, it wants *all* of: two or more recent mocks at or above your pass
mark, coverage past 80%, first-attempt accuracy at least the pass mark, and
calibration not telling you that you are overconfident. Take any one away and it
downgrades.

**It will not be flattered.** 92% correct on a fifth of the syllabus reads as
*"not ready yet — you are scoring well, but on too little of the syllabus"*.
Coverage on its own can never buy a pass claim, and neither can a good score
over a narrow slice.

With too little evidence it says so and tells you what would let it speak —
*"answer at least 30 different questions (you have 12)"* — rather than guessing.
With none at all the card does not appear.

**It never quotes a percentage chance of passing.** The app has not seen your
real paper. A number would be believed, and it would be made up. Open *What that
is based on* and every piece of evidence behind the verdict is listed.

### Reminders that reach you

**Backup & Restore → Study reminders**, or *Remind me* on the countdown card.

It downloads a **calendar file**. Import it once into whatever calendar you
already use — Google, Apple, Outlook — and your own phone reminds you every day
until the exam, at a time you choose. It also marks the day everything should
have been seen once, one week to go, and the exam itself.

Nothing leaves your machine. It is a file you download, exactly like the error
notebook.

**Why not WhatsApp, or a push notification?** Both need a server, and both
would mean your phone number and your study record leaving this machine — the
one thing the app is built not to do. A browser cannot schedule a notification
for tomorrow morning on its own either. A calendar file is the one mechanism
that works on every platform, including iOS, with no account and no backend.

When you do come back after a few days away, the dashboard says so and gives
you today's number. It stays quiet if you practised yesterday.

### A big import is not a long queue

Anything the app could not confirm waits in the checking queue — and if that is
three hundred questions, doing them one at a time is the wrong answer.

Each group in the queue offers **"Do all 312 at once →"**. It opens the Question
Bank filtered to exactly that group with every one of them selected, where
**Classify**, **Verify answers**, **Activate** and **Archive** act on the lot.

Those bulk tools were always there. Nothing pointed at them from the screen
where the problem shows up, which is the only reason anybody was clicking three
hundred times.

### The last week

**Last-mile revision** is the shortlist for the final days, and it is the one
mode with no shuffle in it. Everything else randomises, which is right when you
are working through a bank over weeks and wrong three days out: if you ask for
forty questions you should get the *worst* forty, not a random forty of the bad
ones.

Four reasons put a question on the list, and each question appears once, under
the highest that applies — **wrong last time** (and not since put right),
**you flagged it**, **guessed it right** (which is not the same as knowing it),
**never mastered**. The reason is shown against the question when the answer is
revealed, so you always know why it is in front of you. Before you start, the
setup shows exactly what the list is made of and what a shorter one would leave
behind.

It never shows you a question you have never attempted. Meeting new material in
the last week buys a fresh wrong answer at the moment there is no time left to
fix it — that is coverage work, and the daily target above is what drives it.

### The error notebook

**Backup & Restore → Error notebook**, or the button on Analytics → Mistake.
Everything the app has recorded about what you got wrong, on one printable page
per question: the question with the right answer marked, **the wrong option you
keep choosing** and how often, **why it went wrong** from the causes you
recorded at the time, the explanation, and your own learning point — with a
blank rule to write on where you have not written one yet.

It names a distractor only when one genuinely dominates; where your wrong
answers are split between two options it lists them as fact rather than telling
you what you believe. Grouped by domain, with case-study questions printed
under their scenario — a scenario question with no scenario cannot be revised.

You are asked which you want: everything you have ever got wrong, or only what
you have not since put right. The second uses the same test Last-mile revision
uses, so the page you print and the session you sit cannot disagree.

### Would that have been a pass?

Counting questions is not how any exam is marked. Settings → **How this exam is
marked** takes the four things that decide it: marks a question, marks a
case-study question (usually more — it is answered against two pages of
reading), the pass percentage, and a deduction for wrong answers if your paper
has one. Leave every one of them alone and each question is worth one mark,
nothing is deducted, and your results read exactly as they always have.

Some boards report a scaled figure instead of a percentage. Fill in the lowest,
pass and highest — CISA is 200, 450, 800, and arrives already filled in — and
every result shows that number too, because a CISA candidate thinks in it and
nothing else.

Every finished paper then says where it landed: *"You would have passed, by 1.75
marks — 13.75 of 20 marks · 69% · pass mark 60% · scaled 527 of 800."* Where
your paper deducts, it says what the wrong answers cost and that the ones you
left blank cost nothing, which is the arithmetic behind deciding whether to
guess. The dashboard keeps a trend of your last eight mocks against the pass
line.

Any single question can be worth something different from the rest — set it in
the composer, the question editor, or a **Marks** column in an import file.

### Where the time went

Every answer has always been timed. A finished paper now shows the pace you
actually kept against the pace you needed, and splits the paper four ways on
the median question time:

- **Fast and wrong** — read too quickly. The marks you are giving away to the
  qualifier you skimmed.
- **Slow and wrong** — you did not know it, and paid twice. This is what to
  revise.
- **Slow but right** — you know it but are not fluent. Nothing is wrong with
  the mark; this is what makes you run out of time.
- **Fast and right** — solid.

Each opens to the questions in it. Analytics → **Time** shows the same split
across everything you have answered, and which domains the slow ones sit in.

### A paper with sections

A mock that carries a case-study block is a sectioned paper, because a
two-page scenario and a one-line recall question are not the same unit of work.
The clock is split between them by marks — the same as splitting by question
count when they are worth the same — and you can give the scenarios a set
number of minutes instead, which is how anybody actually plans a paper. The two
always add up to the time limit.

While you sit it, the header names the section you are in and what is left of
its budget, worked out from the pace you are keeping *in that section*. When
you finish, a **By section** table gives each one its answered count, marks,
accuracy, time against budget and time per question, with the overrun in a
sentence: *"Case studies took 43m 20s against the 34m 17s you gave it — 9m 03s
that came out of the rest of the paper."*

### When you changed your mind

Almost everyone believes their second thought is better than their first. The
app now keeps the receipts: every answer you change in a mock is recorded, and
the results say how many you changed, how many turned a right answer wrong, how
many rescued a wrong one, and what that came to in marks — with the ones it
cost you listed by name, showing what you first chose and what you settled on.

It is judged on your **first** answer against the one you submitted, not each
hop in between. Changing your mind and landing back where you started costs
nothing and gets no line. And it says nothing at all until at least four
changes actually decided something, because telling you your instinct is better
on a sample of two would be worse than silence — you would take it into the
real exam.

### Why the option you picked was wrong

An MCQ's wrong answers are the syllabus. Each one is a specific misconception
somebody thought worth writing down, and the one you pick says more about your
understanding than the fact that you got it wrong.

So every option can carry its own reasoning — optional, and absent from most
questions. When it is there, the reveal answers **you**: *"Why C is wrong. C is
the detective control; the question asked which is preventive."* The correct
option's reasoning follows, and the rest are one click away.

Add it in the composer or the question editor (the **Why?** button beside each
option), or bring it in: a `Why A` / `Why B` column in a spreadsheet, or a
`rationale` on a JSON option. The export and the printable sheet carry it back
out.

### What keeps catching you

Every answer you have ever given recorded which option you picked. The moment
an answer is revealed, the app now says so:

> That is the fourth time you have missed this. You have chosen "A documented
> capacity planning standard" every time.

Options are named by their text, not their letter — letters move, because the
options shuffle. Getting it right after missing it says that too.

The question's own detail shows the full breakdown of what you have chosen and
how often. **Analytics → Mistake** lists the questions that keep catching you
and what each one catches you with, and the Question Bank has a **missed more
than once** filter. Where no single wrong option dominates it says so rather
than inventing a pattern — one miss is not a habit, and an even split is not a
belief.

### Did you know what you thought you knew?

Every mode but a timed mock asks how you got to your answer. Analytics →
**Confidence** finally tells you whether the claim held: *"You are
overconfident. When you said you knew it, you were right 65% of the time — the
topics you feel safest on are the ones to check."*

Underneath, the same figure by domain, worst first. The headline says whether
you have the problem; that table says which part of the syllabus to distrust,
which is the part you can do something about before the date.

**Practice settings are per course.** Mock length, time limit, mastery target
and all spaced-repetition intervals are set separately for CISA and DISA, since
they are different exams. Settings shows a badge telling you which you are
editing. Appearance and shuffle behaviour are shared across courses.

### Games

**Games** is a shelf, not a mode. Two are built in — *Kab Banega Crorepati*, a
fifteen-rung quiz-show ladder with lifelines, and *Balloon Pop*, where the
options float away and you shoot the right one.

Games live in a shared library and you add them to a course. That tagging is
the whole mechanism: it tells the game which question bank to draw from. The
same game can sit on as many courses as you like, and a course starts with an
empty shelf.

Nothing stops you adding a game to a course it was not written for. A game that
needs specific subject matter — spotting network hardware, say — will still run
on a tax bank; it just will not be worth playing there. Each game's info button
says what it needs and what it suits, and the difference matters: the app can
check structure (enough questions, the right number of options) and enforces
that, but it cannot judge whether a game fits your subject. Only you can.

Games draw from the same pool practice does — Active questions with a verified
answer — but they **never write back**. No attempt is recorded, no review date
moves. Playing cannot disturb your spaced-repetition schedule. They never draw
case-study questions, for the same reason no other mode does.

## 5. Case studies

Some questions only make sense against a scenario — a page or two of context,
followed by four or five questions about it. Mixed into the ordinary bank they
would turn up in Learning, Weak topics, Spaced repetition and every game
stripped of the only thing that makes them answerable. So they are a **second
bank**, with its own tab.

**Where they appear.** Two places, both deliberate:

- **Case study questions**, a practice mode that draws whole scenarios.
- **Timed mock exam**, where you say how many case-study questions the paper
  should carry. That number is remembered per course, alongside the mock's own
  length and time limit, and defaults to none.

Nothing else reaches them — not the other seven modes, not the games.

**Cases are never split.** Ask a mock for twenty and it works out which whole
scenarios come closest: four fives is twenty exactly; if your scenarios are
sixes and fours it will tell you what it actually reached. You are never given
three of a scenario's five questions, because that means reading two pages for
a fragment. The section sits at the end of the paper, and the question palette
shows where it starts, so you can see the long reads coming.

**Reading it.** On a wide screen the scenario sits beside the question and
scrolls on its own, so you keep your place in it across all five questions. On a
phone it stacks above the question and collapses.

**Getting them in.** Write one on the **Case Studies** tab — a title, the
scenario with no length limit, then its questions through the same composer as
any other. Or import: the JSON template nests each scenario's questions inside
it, so the link cannot be lost; the spreadsheet template groups rows by a shared
**Case ref** column and takes the passage from a single cell, so you need not
repeat two pages down every row. Both go through the same preview, where the
scenario itself is still editable, and the same duplicate check.

Archiving a case study takes its questions with it, and is reversible. The
Question Bank has a **Standalone / Case study** switch that hands its filters,
bulk actions and export to either bank; Analytics has a **Both / Standalone /
Case study** switch, so you can read your scenario performance apart from the
rest or together with it.

Spaced repetition never surfaces a case-study question on its own. Anything due
comes back through Case study practice instead.

### Installing it as an app

From Chrome or Edge, the address bar offers an **Install** button; on Android,
*Add to Home screen*; on iOS, Share → *Add to Home Screen*. It then opens in its
own window with its own icon, no address bar, and works with no connection.

This changes nothing about your data. It is the same app, the same browser
database, the same folder on your disk. Nothing is uploaded by installing it,
and there is no account to make.

### Opening it without a network

The app keeps a copy of itself so it opens on a train. Everything else was
already offline — the font and the app manifest are embedded in the page, and
your bank is in the browser database and in your own data folder — so the only
thing that ever needed a connection was fetching the page itself.

It is on by default, and it never gets in the way of an update: **when you are
online you always get the current version**, and the stored copy is only ever
the fallback. Settings → **Offline** says which state it is actually in, and
turns it off entirely if you would rather it did not.

This is why the app is `index.html`, `sw.js` and `manifest.webmanifest`. A
browser will not accept a service worker inlined into a page, and it discards a
manifest supplied as a `data:` URI — both have to be real files in the same
folder. If you only ever copy `index.html`, everything works exactly as before;
you simply need the network to open it, and it cannot be installed.

### Keeping your own copy of the app

Backup & Restore → **Keep your own copy of the app** → *Download a copy* gives
you a zip of the whole thing: `index.html`, `sw.js`, `manifest.webmanifest`, the
Windows launcher, and a `START-HERE.txt` explaining what each file is. Unzip it
anywhere and run it exactly as in section 1.

The point is independence. Once you have that zip you are not relying on
whoever published the app, or on that address still being there, or on nothing
ever going wrong with it. Your copy is frozen at the version you took, and it
carries on working exactly as it does today.

That cuts both ways, and the app says so rather than hiding it: **your copy
never updates itself.** Nothing reaches back to where you got it from — no
version check, no download, no notification. A fix or a new feature reaches you
only when you take a fresh copy, so it is worth doing that occasionally.

**Your bank does not travel inside the zip, and this is the one thing to get
right.** The app is the program; your questions and your history are data, and
they live in the browser's database and in your data file. A local copy runs at
a different address, and a browser keeps a separate database per address — so a
copy opened without either of those set up looks completely empty. Nothing is
lost, it simply is not there.

So the app will not let you walk into that. If you have questions in the
browser but no connected folder, no Drive, and no backup in the last week, the
download is refused and it offers the two things that fix it: connect a folder,
or take a backup. Either one makes the bank a file, and the copy opens the same
file. With a folder connected there is nothing else to do — point the copy at
it and everything is there.

Two smaller things worth knowing. The zip contains a `.bat` and a `.ps1`, and
some browsers and some workplace machines warn about those or strip them. They
are plain text — a nine-line `.bat` and a commented PowerShell script that
starts a local server bound to the loopback address. `START-HERE.txt` says what
they are, and you can read both in Notepad before running anything. And if the app cannot
fetch one of the optional files it does not fail silently — it names the file in
`START-HERE.txt` and tells you what you are missing.

## 5b. Sharing a bank with other people

If you teach, or you simply want to hand a friend the bank you built, the app
writes a file for it and reads that file back through the ordinary import.

**To share:** Backup & Restore → **Share with someone else…**. It writes
`<COURSE>-shared-bank-<date>.json` containing only questions that already reach
practice — the wording, the options, the answers, the explanations, the
domains, the difficulty and the marks.

**Your own progress is not in it, and cannot be.** The file is written in the
ordinary import format, which has no field for a mastery score, an attempt
count, a review date or a flag. Nothing is stripped after the fact and could be
forgotten: only listed fields are written at all — and that list deliberately
leaves out **My learning point**, the note field on the reveal panel. It is
your own reflection, not curated content, and it stays in your bank even when
the question it is attached to gets shared.

**The answers arrive confirmed.** Only questions that already reach practice
are exported, so every answer in the file is one you checked. The file records
that, and the receiving copy ticks *"treat an answer printed in the source as
verified"* for them — otherwise a shared bank lands with every answer needing
confirmation again, which looks exactly like an export that lost the answer
key. They can still clear the box and check all of them themselves.

**To receive one:** drop it on Add Questions like any other file. It goes
through the same duplicate check and the same confirmation screen, into your
own bank, with your own Question IDs. Tick *"treat an answer printed in the
source as verified"* and it reaches practice immediately — that tick is you
saying you trust whoever sent it, which is a decision the app will not make on
your behalf.

### Putting one inside the app, for a group

If you publish this app for a class, `data/starter-index.json` is the one file
you edit to reach everybody. Students see the material on **Add Questions**, one
tap to import.

```json
{
  "files": [
    { "file": "data/shared-cisa-domain5.json", "course": "CISA",
      "label": "Domain 5 — 120 questions",
      "note": "Sat alongside chapter 5. Do these before Sunday's mock.",
      "questions": 120, "from": "2026-08-01", "until": "2026-09-30" }
  ],
  "notices": [
    { "text": "Mock 3 is on Sunday. Sit it in one go, timed.",
      "course": "CISA", "kind": "note", "until": "2026-09-08" },
    { "text": "Read the last sentence of the stem first.", "kind": "tip" }
  ],
  "supportGroup": {
    "label": "Ask on WhatsApp", "url": "https://chat.whatsapp.com/…",
    "note": "Something not working, or a question about the app itself? Ask here."
  }
}
```

- **`from` / `until`** are `YYYY-MM-DD`, both ends inclusive — *until 30
  September* means all of the 30th. Outside that window the entry is not
  offered. **This is tidying, not a control**: the file stays in your
  repository until you delete it, and anyone with the direct URL can still
  fetch it.
- **`course`** matches the course code. Omit it on a notice to show it to
  everyone.
- **`notices`** appear on the dashboard. `kind` is `tip` (quiet) or `note`
  (amber). This is how you send exam tips or a word of encouragement without
  needing anywhere to host them.
- **`supportGroup`** is one link for people who hit a problem with the app —
  it appears in **Settings → About and licence**, next to the licence and the
  shortcuts, which is where somebody looks when something is wrong. Not on the
  dashboard: that would put a support link in front of every student every day
  for something they need twice a year. Only `http`/`https` URLs are rendered.
  The app also says, beside it, that joining a group chat shows your number to
  the people in it — true of any group link, and worth saying in an app that is
  careful about this elsewhere.
- A listed file that is not actually there shows **nothing** rather than a
  broken button, so a typo is quiet rather than embarrassing.

`.gitignore` is set up for exactly this: `data/starter-index.json` and
`data/shared-*.json` are committable, and everything else under `data/` stays
on your disk. Rename an export to `shared-something.json` before committing it.

**Only publish what you have the right to publish.** A bank you wrote is yours.
A bank extracted from a publisher's material is theirs, and a GitHub Pages site
is public — see `GITHUB-PAGES.md`.

### There is no message board, deliberately

Students cannot post back through the app, and there is no plan to let them. A
page that accepts writes from anyone with the link, with no account, gets
spammed the moment the URL travels — and whatever appears on it appears under
your name.

Nor does the app try to be where students talk to each other. They already have
groups for that, set up around whichever paper and coaching class they are
doing, and a study group bolted onto a practice app would be a worse version of
one they are already in. `supportGroup` is a narrower thing on purpose: **the
place to report a problem with the app itself.**

## 6. Checking what the app could not confirm

Adding questions is two steps, both on the **Add Questions** screen.

**Step 1 — bring questions in.** Drop files, paste text, or add from an image.

**Step 2 — check what needs confirming.** Questions land here when the app could
not be certain: the source stated no answer, or there was no reliable way to
tell the domain. They stay out of practice until you confirm them, one click
each — practising a question whose answer was guessed is worse than not
practising it.

The step badge shows how many are waiting, and the sidebar carries the same
count on Add Questions, so a queue left half-finished is never invisible.

## 7. Known limitations

**Complex PDFs may refuse to import.** The built-in PDF reader has no external
dependencies and handles straightforward text-layer PDFs. It cannot reliably
read PDFs with compressed object streams or a linearized layout. When it cannot
read one it says so and suggests a route, rather than importing nonsense. Open
such a file in Word and save as `.docx`, or use **Add from image** page by page.
Bundling PDF.js is the proper fix if this matters to you.

**No built-in OCR.** "Add from image" gives you crop, rotate, greyscale and
contrast alongside a transcription pane — you type what you see with the image
next to the form. No offline OCR engine is small enough to bundle honestly. Drop
a `vendor/tesseract.min.js` into the folder and the app will use it.

**Suggested vs verified classification is not visible in the bank table.** When
the app guesses a domain from keywords it records that it was a guess, but the
table shows only the domain. Question detail → Classification shows which it
was.

**Scale.** Comfortable to roughly 10,000 questions across courses. Practice
speed does not degrade — selecting a 150-question mock from 2,000 takes about a
millisecond. The constraint is attempt history, which grows without bound; at
around 50 MB the periodic full rewrites become slow enough to be worth archiving
old attempts. The app warns you past 12 MB and rewrites the file less often as
it grows.

**Deliberately not included:** it does not read your notes, chat with you,
generate questions, or sync anywhere.

## 8. If something goes wrong

**"Storage unavailable" at startup** — you opened `index.html` directly, or you
are in a private window. See section 1.

**A `.docx` will not import** — if it is a legacy `.doc`, open it in Word and
save as `.docx`.

**An import produced nonsense** — nothing was written. The staging screen is a
preview. Cancel it and try **Paste raw text** so you can see exactly what the
parser extracted, or pick a specific parsing template instead of auto-detect.

**Read-only, "your data file is gone"** — the app stopped writing on purpose.
Your bank is safe in the browser. Use the dialog to write the file again, or
point at a different folder.

**Built-in self-test:** Settings → Diagnostics → Run tests. 50 automated tests,
listed in `TEST-CHECKLIST.md`.

## 9. Licence

Copyright 2026 Vighnesh CN. Licensed under the
[PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0),
full text in [`LICENSE`](LICENSE).

**You may**, for free and for any noncommercial purpose: use it to study, read
and modify the source, and share copies — including changed ones — so long as
this licence travels with them. Use inside a school, university, charity,
public research body or government institution counts as noncommercial,
whatever its funding.

**You may not** sell it, sell access to it, bundle it into a paid product,
service or subscription, or use it to deliver paid coaching or training.
Commercial use is not granted here; contact the copyright holder if you want a
separate commercial licence.

The same terms are shown inside the app, under Settings → About and licence,
and from the © Licence link in the sidebar.

### This covers the software, not your questions

The licence covers this application. It does **not** cover question content you
import. Questions, answers and explanations from past papers, textbooks and
paid courses belong to whoever wrote them — usually a publisher or a
certification body. Importing them for your own private study is one thing;
publishing or redistributing them is another, and nothing in this licence
grants permission to do so. `.gitignore` deliberately keeps your question bank
out of this repository for that reason — see `GITHUB-PAGES.md` before you
publish anything.
