# Publishing this to GitHub Pages

The app is a single self-contained `index.html`. Pages serves it as-is — there
is no build step, no framework, no Actions workflow to configure.

---

## Before you publish: what must not go in the repository

**A published Pages site is public. Always.** Making the *repository* private
hides the source code; it does not make the site private. Anyone with the URL
can still load every file the site serves. Truly private Pages needs GitHub
Enterprise Cloud with access control — it is not available on Free, Pro, or
Team.

So the rule is simple: **if you would not put a file on a public web server, do
not commit it.**

That means no question files you do not own the right to redistribute. Exam
mock papers and practice banks from professional bodies and paid courses are
copyrighted; extracting them for your own study is one thing, and republishing
them at a public URL is another. Keep them on your disk and import them into the
app locally.

The included `.gitignore` blocks the obvious cases — your live database,
journal, backups, and any `data/` folder. Check it is present before your first
commit.

## Publishing, step by step

1. Create a new repository on GitHub. Public or private both work for Pages on a
   free account **only if public**; private-repo Pages requires Pro or above.
   The published site is public either way.

2. Upload these files to the repository root:

   ```
   index.html                 the app
   .gitignore                 keeps your bank out of the repo
   README.md
   ARCHITECTURE.md
   TEST-CHECKLIST.md
   GITHUB-PAGES.md
   Start MCQ Mastery.bat      for running it locally
   serve.ps1
   ```

   Uploading through the web interface will not accept a file named
   `.gitignore` by drag-and-drop reliably. Use **Add file → Create new file**,
   name it `.gitignore`, and paste the contents in.

3. Repository **Settings → Pages**.

4. Under **Build and deployment**, set **Source** to **Deploy from a branch**.

5. Set **Branch** to `main` and folder to **`/ (root)`**. Save.

6. Wait a minute or two. The page will show your URL:
   `https://<your-username>.github.io/<repo-name>/`

That is the whole process. No workflow file, no Jekyll configuration.

## After publishing

**Connect a data folder first, before you import anything.** Settings → Where
your data lives → Connect a folder. Point it at somewhere on your disk that is
*not* this repository — `D:\MCQData` or similar.

This matters more than it sounds. Browser storage is tied to the exact address
you are using, so a bank built at `localhost:8080` is invisible at
`yourname.github.io`, and vice versa. They are separate databases. A connected
data folder is what lets both read the same bank. Without one, pick one address
and never switch.

## Verifying you did not publish something you meant to keep

Load these in a private browsing window, where you are not signed in to GitHub:

- `https://<your-username>.github.io/<repo>/` — should load the app
- `https://<your-username>.github.io/<repo>/data/starter-index.json` — should
  return **404**
- Any question file you were worried about — should return **404**

A 404 in a signed-out window is the confirmation. Checking while signed in
proves nothing.

Note that Pages caches aggressively. After deleting a file, give it a few
minutes before concluding it is still exposed.

## Unpublishing

Settings → Pages → Source → **None**. The site goes offline immediately. Your
data is untouched — it was never on GitHub. Use the `.bat` launcher locally
instead.

## Updating the app later

Replace `index.html` and commit. Pages redeploys within a minute or two.

Your bank is not affected by an update: it lives in your data folder and in
browser storage, both independent of the app file. Hard-refresh (Ctrl+Shift+R)
if you still see the old version — Pages caches.

## If history contains something it should not

Deleting a file in a new commit does not remove it from earlier commits. Anyone
who can clone the repository can still recover it.

The web interface cannot rewrite history — it only offers deleting a branch or
deleting the whole repository. Rewriting must be done locally and force-pushed:

```bash
pip install git-filter-repo
git filter-repo --path data/ --invert-paths
git remote add origin https://github.com/<you>/<repo>.git
git push --force --all
```

Even then, GitHub can retain unreferenced objects reachable by direct commit
SHA. For certainty, delete the repository and create a fresh one — for a repo
this small, that costs almost nothing and is the only guarantee.
