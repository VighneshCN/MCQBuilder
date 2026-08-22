# Test checklist and results

Run from **Settings → Maintenance → Run built-in tests**. The suite runs against
a scratch course, so it never touches your real bank.

**Current result: 128 passed, 0 failed, of 128.**

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
- [ ] Settings → Diagnostics → Run tests reports 50 of 50
