# MCQ Mastery

A local-first MCQ practice and revision app. One universal question bank per
course, permanent Question IDs, full source traceability, duplicate detection,
and attempt history that survives question edits.

Everything runs in your browser. No backend, no cloud database, no API keys, no
network calls at runtime. Your question bank never leaves your machine.

Ships with two courses configured — **CISA** and **DISA AT** — and no questions.
You import your own.

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

**Download CSV / JSON templates** in Add Questions gives you a worked example of
every supported field. The app generates these itself; there are no template
files to find.

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

Eight modes: Learning, Domain drill, Weak topics, Incorrect & guessed, Mixed
revision, Timed mock exam, Spaced repetition, Custom practice.

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

Mock exams draw questions weighted to the course blueprint.

**Practice settings are per course.** Mock length, time limit, mastery target
and all spaced-repetition intervals are set separately for CISA and DISA, since
they are different exams. Settings shows a badge telling you which you are
editing. Appearance and shuffle behaviour are shared across courses.

## 5. Checking what the app could not confirm

Adding questions is two steps, both on the **Add Questions** screen.

**Step 1 — bring questions in.** Drop files, paste text, or add from an image.

**Step 2 — check what needs confirming.** Questions land here when the app could
not be certain: the source stated no answer, or there was no reliable way to
tell the domain. They stay out of practice until you confirm them, one click
each — practising a question whose answer was guessed is worse than not
practising it.

The step badge shows how many are waiting, and the sidebar carries the same
count on Add Questions, so a queue left half-finished is never invisible.

## 6. Known limitations

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

## 7. If something goes wrong

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
