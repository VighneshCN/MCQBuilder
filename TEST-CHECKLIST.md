# Test checklist and results

Run from **Settings → Maintenance → Run built-in tests**. The suite runs against
a scratch course, so it never touches your real bank.

**Current result: 181 passed, 0 failed, of 181.**

Verified against the exact `index.html` in this repository, not merely against
the source it was built from, and run headlessly in Chromium as well as in the
app's own dialog.

The groups below name the checks in each area. Where a group's heading count is
lower than the number of assertions it covers, that is because several of these
tests assert a whole family of cases in one go — "no ordinary filter can reach a
case-study question" runs eleven filters, and "a case study is never split" runs
nine different requested counts.

---

## 1. Automated tests

### Option handling (3)
1. Seeded shuffle is reproducible and loses nothing
2. Option shuffling never changes which option is correct
3. Locked option order is respected — questions saying "Both A and B" keep their order

### Duplicate detection (5)
4. Punctuation-only differences are treated as exact duplicates
5. Same stem with materially different options is not a duplicate merge
6. Same concept through different facts stays distinct
7. Conflicting correct answers are detected, not merged
8. Same question from two sources merges to one canonical record

### Parsing and import (8)
9. Numbered stems with lettered options parse
10. An answer key printed separately is matched back by question number
11. A stray capital letter does not become a phantom option
12. Tabular questions parse from tab-separated rows
13. CSV rows map to candidates and resolve the answer letter
14. A missing answer produces a question that cannot be practised
15. A question with fewer than two options is held back
16. Unreliable domains are left unmapped rather than guessed

### Question identity (2)
17. Question IDs are sequential, prefixed and never reused
18. A restore collision issues a new ID and keeps the old one as an alias

### Learning and scheduling (5)
19. Spaced repetition intervals follow the stated ladder
20. A guessed-correct answer is not treated as mastery
21. Repeating a question immediately does not inflate mastery
22. Weakness reports insufficient evidence on a small sample
30. A timed mock answer does not extend the review interval

### Session selection (4)
23. Domain-weighted selection distributes by blueprint and reports shortfalls
24. Session selection never repeats a question
25. Filters isolate incorrect, guessed and due questions
47. Only active, verified questions can enter a session

### Saving to your data file (8)
26. File sync covers every store except the handle store
27. File payload round-trips questions and attempts including their keys
28. Read-only blocks writes but never blocks reconnecting
31. An answer journals a small entry instead of rewriting the bank
32. Broad changes escalate to a full snapshot rather than a huge journal
33. Replaying a journal survives a half-written final line
50. Attempt history stays linked to the version answered

### Protecting the file from loss (8)
35. A deleted data file is detected instead of silently recreated
36. An externally rewritten file is a conflict, but a re-synced identical one is not
37. A first write is allowed, because there is nothing to conflict with yet
38. A file deleted while the app was closed is not resurrected on next launch
39. Once a file is known to exist, the write path never creates it
40. An empty or badly shrunken bank cannot overwrite a full file
41. The shrink consent is one-shot, not a standing permission
42. A save that cannot be read back is reported, not trusted

### Scale (3)
43. Duplicate detection stays fast as the bank grows
44. Comparison caches never reach the data file
45. Editing a question invalidates its cached comparison data

### The two banks (7)
51. The two banks are separated by one predicate, and it holds both ways
52. No ordinary filter can reach a case-study question — every filter the modes
    use, including spaced repetition's, run against case questions built to
    match them
53. Games draw through the same seam, so they cannot see a scenario either
54. A case study is never split, whatever number is asked for
55. Uneven case studies still come whole, and the closest fit wins
56. A case block is contiguous, in printed order, and describes itself
57. The same seed composes the same case section twice

### The import contract (5)
58. A hand-supplied column mapping is used instead of the header row
59. A recognised header still parses exactly as it always did
60. JSON case studies carry their own questions, in order
61. Spreadsheet rows sharing a case reference become one scenario
62. Duplicate detection is partitioned, and still works inside each bank

### Writing a question by hand (2)
63. A hand-written question earns exactly the status its content deserves
64. Blockers name what is left to do, and go quiet when nothing is

### Case study storage (3)
65. Case study IDs are their own sequence and never collide with question IDs
66. Case studies reach the file, the backup and the merge
67. A question whose scenario has gone is reported, not left to be answered

### Defects an audit of the above turned up (7)
68. A case-study candidate is in the case bank from the moment it is parsed
69. A scenario nobody can read is not one anybody can be asked about
70. The due count and the mode behind it cannot disagree
71. Restoring an archived case study does not lose a conflict
72. One case reference is one scenario, however often a file repeats it
73. A scenario already in the bank is reused, not written a second time
74. A paper says what it was actually made of

### Marking (7)
75. At the defaults, marks and the question count are the same number
76. A question’s own marks beat the course rate, and a case question takes the
    case rate
77. Negative marking takes a share of each wrong answer, and nothing from a blank
78. Negative marking can never take a score below zero
79. The pass verdict is right either side of the line, and on it
80. A scaled score puts the pass percentage exactly on the pass score
81. A paper keeps the marks and the scheme it was sat under

### Time and confidence (5)
82. The time split cuts on the median and files every answer exactly once
83. A paper with no variation in time is not split down the middle arbitrarily
84. Answers with no recorded time are excluded, not treated as instant
85. Calibration counts each level and signs the gap the right way round
86. Calibration says nothing rather than dividing by zero

### Per-option reasoning and distractors (7)
87. An option carries its own reasoning, or carries no field at all
88. Editing the reasoning is a material change, like editing the explanation
89. Reasoning survives both import shapes
90. The distractor profile counts by option and reports by text
91. One miss is not a pattern, and an even split is not a belief
92. An option a later edit removed is counted apart, not silently dropped
93. The line said at reveal is right, or is not said at all

### Sections and changing your mind (8)
94. A change keeps the first answer, however many times you go round
95. Changes are priced on the first answer against the last
96. An untouched paper reports nothing rather than zeroes
97. A section budget follows the marks, and the parts sum to the whole
98. Only a mock with a case-study block is sectioned
99. A section reports what it was asked and what it cost
100. Durations past an hour read as hours
101. Marks are said out loud with the right plural

### Getting to the date (9)
102. Every question owes exactly one job, and the jobs add up
103. The daily target counts today, and never divides by nothing
104. A date in the past, and an empty bank, give an answer rather than a NaN
105. Today’s progress counts questions, not attempts
106. The last mile is worst first, one reason each, and the same every time
107. The last mile never puts an unseen question in front of you
108. The notebook and the last mile agree on what is still broken
109. The printed page is built in one place
110. The offline switch is honest about where it cannot work

### Out of the student's way (8)
111. What blocks practice is written once, in the status table
112. A question nobody has filed still practises; one nobody can mark does not
113. A bank that was already fine is completely unaffected
114. A feature that has nothing to run on says so, and lets go by itself
115. A mode with nothing to draw closes; one that is merely quiet stays open
116. A mock opens at something the bank can actually build
117. The marking scheme reads as a sentence before you open the card
118. Nothing is a blocker that the composer will not also let you save
119. A bank nobody has filed still fills a mock, and is told so once
120. The storage bar asks where the bank lives, not whether a token is live

### Everything else (4)
29. Practice settings are per course, app preferences are shared
34. Appearance resolves Light, Dark and Auto correctly
46. The app never advertises question files it has not confirmed
48. ZIP write then read returns the same bytes
49. CSV round trip survives quotes, commas and newlines

## 2. Measured performance

Benchmarked at 5 courses × 2,000 questions = 10,000 questions, with 30,000
attempts.

| Operation | Result |
|---|---|
| Select a 150-question mock from 2,000 | 1 ms |
| Filter 2,000 questions | 1 ms |
| Parse the whole 30 MB database at startup | 149 ms |
| Serialise the whole database for a full write | 0.8 s |
| Import 2,000 questions into a 10,000-question bank | 8.6 s |
| One answer, journalled | ~1.6 KB written |

Duplicate detection was 271 ms per question before the indexing was fixed —
importing 2,000 would have taken about nine minutes. It is now 3.8 ms per
question, 71× faster, with accuracy checked separately: against a
10,000-question bank, 18 of 18 planted duplicates found (exact copies,
punctuation and case variants, rewordings) with 0 false positives on 10
genuinely new questions.

## 3. Validated against real documents

Extraction was tested with the app's own parser against real exam-prep
documents, not synthetic fixtures.

| Source | Detected | With an answer | With an explanation |
|---|---|---|---|
| A 1,035-question `.docx` | 1,043 candidates | 1,035 (99.2%) | 1,031 (98.8%) |
| A 310-question `.docx` | 310 candidates | 310 (100%) | 270 |
| A 530-page mock-paper PDF | 1,580 candidates | 842 | 1,025 |

Eight parsing bugs were found this way that all passed the synthetic tests,
including a header-stripper that silently deleted the answer line from most
questions in a long document, and explanations lost when a source restated the
answer in the same paragraph.

## 4. Manual checks worth running after a fresh deploy

Automated tests cannot verify rendering or real browser storage.

- [ ] App boots over `http://localhost` or your Pages URL without a storage error
- [ ] Both courses appear in the course picker
- [ ] Settings → Where your data lives → Connect a folder succeeds
- [ ] `mcq-mastery-data.json` appears in the folder you chose
- [ ] Import a small file; the reconciliation screen appears before anything is written
- [ ] Reconciliation totals balance — detected equals imported plus held plus rejected
- [ ] Answer one question; the journal file appears and grows
- [ ] Close the tab and reopen; your answer is still there
- [ ] Delete the data file with the app open; within 30 seconds it goes read-only and offers to fix it
- [ ] Start a timed mock; the timer runs and nothing reveals until submission
- [ ] Add Questions → step 2 lists unconfirmed questions; confirming one takes a single click
- [ ] Backup & Restore exports a ZIP; restore previews it before changing anything
- [ ] Toggle Light / Dark / Auto; check the practice screen and bank table
- [ ] Resize to phone width; the ☰ menu appears and opens the sidebar
- [ ] Edit a question that has attempt history; history survives and the version increments

### Writing questions by hand

- [ ] Question Bank → New question: open it, type a stem, then close it. No
      record appears and no Question ID is spent (Settings → Question ID register)
- [ ] Type a complete question: the readiness strip says "Ready to practise",
      and Save makes it available in Learning immediately
- [ ] Type it a second time, slightly reworded: the duplicate warning names the
      first one and offers a side-by-side comparison
- [ ] Save & add another keeps the domain and clears the question

### Importing a file the app cannot read

- [ ] Import a `.csv` with recognised headings — no mapping dialog appears
- [ ] Rename those headings to nonsense and import again — the mapping dialog
      appears, refuses to continue until the question and two options are named,
      and lands the same questions once mapped
- [ ] Re-save that file as `.xlsx` and import it — identical result
- [ ] "See every column and key the app reads" lists the headings that worked

### Case studies

- [ ] Case Studies → New case study: paste a one-to-two page scenario; the word
      count and reading time are shown and nothing is truncated
- [ ] Add three questions to it; they appear in order and count as ready
- [ ] Import the case-study JSON and CSV templates — both produce a scenario
      with its questions linked and in order
- [ ] Question Bank opens on **Standalone**; the case questions are only on the
      **Case study** side
- [ ] Run Learning, Weak topics, Spaced repetition, Custom and a game — no
      case-study question appears in any of them
- [ ] Practice → Case study questions draws whole scenarios, passage beside the
      question, scrolling independently
- [ ] Mock exam → ask for a number of case-study questions: the paper reports
      what it actually reached, the section is last and whole, and the palette
      shows where it starts
- [ ] Narrow the window to phone width mid-scenario: the passage stacks above
      the question and collapses
- [ ] Analytics → switch Both / Standalone / Case study; the attempt counts and
      the coverage denominator both follow
- [ ] Archive a case study: its questions leave practice with it, and Restore
      brings both back
- [ ] Export a backup ZIP; it contains `data/caseStudies.json`

### Marking, time and confidence

- [ ] On a course where nothing about marking has been set, sit a mock: no
      Marks tile, no Marks column, and the score and accuracy read exactly as
      before
- [ ] Set 2 marks for case-study questions, a 60% pass and 0.25 negative
      marking; check the verdict, the margin, the scaled score and the
      deduction line against a hand-worked paper
- [ ] Change the marks after sitting that paper — its total and verdict must
      not move
- [ ] The dashboard mock trend draws the pass line and the last eight mocks
- [ ] A finished paper shows the pace line and four cells whose counts sum to
      the number of timed answers; each cell opens
- [ ] Answer a Learning session with a deliberate mix of confidences; the
      calibration table matches a hand count, and a timed mock produces no
      calibration card at all
- [ ] Analytics → Time and → Confidence both render on an empty bank without
      dividing by zero

### Per-option reasoning and distractors

- [ ] Import a file with Why A / Why B columns; answer one of those questions
      wrongly — the reveal names why *your* option was wrong before why the
      right one was right
- [ ] The composer and the editor both open a reasoning box from the **Why?**
      button, and it stays open on a question that already has one
- [ ] Export the bank: the Why columns are there and round-trip
- [ ] Miss the same question three times choosing the same option — the reveal
      says so and names the option by its text
- [ ] Miss one three times choosing three different options — it says no single
      option dominates rather than inventing one
- [ ] Analytics → Mistake lists the repeat offenders; Question Bank filters to
      them

### Sections and changing your mind

- [ ] Configure a mock with case-study questions: the section note reacts to
      the question count, the case count and the time limit
- [ ] Give the scenarios a set number of minutes — the other section takes the
      remainder and the two sum to the limit
- [ ] Sit it: the header names the section and counts down its own budget, and
      turns red when the section is projected to overrun
- [ ] Finish: the By section table is there, and the overrun sentence names the
      section that ate the clock
- [ ] Change four answers in a mock; the results say how many went each way and
      what it cost in marks, and list the ones it cost
- [ ] Change one and change it back — it is counted as changed but costs
      nothing and is in none of the three outcomes
- [ ] A mock with no case-study questions has no sections and no By section
      card, exactly as before
- [ ] Import the same case-study file twice — the second time adds no new
      scenarios and flags every question as a duplicate
- [ ] Blank a scenario's text: its questions leave the practice count, Practice
      says how many are held back and why, and no session draws them
- [ ] Mock exam → type a case-study count: the line under it says the number the
      paper will actually land on, before you start
- [ ] Finish any session: "How this paper was made up" states the case-study
      section and any quota that could not be met
- [ ] Backup & Restore → Printable HTML: each scenario is printed once with its
      questions under it, never a case question on its own
- [ ] Settings → Diagnostics → Run tests reports 50 of 50

### Getting to the date

- [ ] With no exam date set, the dashboard is exactly as it was — no countdown
      card, no "Exam in" figure, just the one line offering to set a date
- [ ] Set a date three weeks out: the three buckets add up to the backlog, and
      hand-counting the bank agrees with them
- [ ] Answer some questions: today's figure moves by the number of *distinct*
      questions, not by the number of attempts
- [ ] Set the date to today, and to a date in the past — both read sensibly and
      neither shows a negative countdown or target
- [ ] Last-mile revision: the setup shows what the list is made of, and asking
      for fewer keeps the worst rather than sampling
- [ ] Sit it: each question carries the reason it is on the list, and no
      question you have never attempted appears
- [ ] Export the error notebook both ways: "not since fixed" leaves out one you
      have put right, and "everything" includes it
- [ ] Open the notebook: the option you keep choosing is named, the cause and
      explanation are there, and a case-study question sits under its scenario
- [ ] Load the app, then go offline and reload — it opens
- [ ] Back online, replace index.html and reload — the new version is served,
      not the stored copy
- [ ] Settings → Offline → turn it off, reload offline — it correctly does not
      open, proving the switch really unregisters

### Out of the student's way

- [ ] Make a course with your own domains (not a CISA/DISA template) and import
      a file with no domain column: every question is practisable, and the
      review badge does not light up
- [ ] Question Bank shows them as **Unclassified**, and the queue groups them
      under "already in practice"
- [ ] Open a mock on that bank: both mix toggles are disabled, each saying what
      it runs on and how to feed it
- [ ] Grade one question's difficulty as you practise — the difficulty mix
      switches itself on with no reload
- [ ] File one question under a domain — the domain mix and Domain drill wake up
- [ ] Fresh course, no attempts: Practice dims the modes that cannot help yet;
      the three with nothing at all to draw do not open, Weak topics and Domain
      drill still do
- [ ] The mock dialog opens with no warning, asks how many and how long first,
      and says why it opened shorter than your usual paper
- [ ] Settings → *How this exam is marked* is folded, with the scheme in force
      readable on the fold
- [ ] Add Questions shows no six-step map until a file is in
- [ ] Install it from the browser's own Install button; it opens in its own
      window and still works with the network cut
- [ ] With Drive connected, reload — the bar says "reconnecting", never "Local
      only"; go offline and reload — it says offline and promises to sync
