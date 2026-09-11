/*
  MCQ Mastery — the offline shell.

  Copyright 2026 Vighnesh CN.
  Licensed under the PolyForm Noncommercial License 1.0.0.
  https://polyformproject.org/licenses/noncommercial/1.0.0

  ---------------------------------------------------------------------------
  Why this file exists at all, when everything else in this app is one HTML
  document: a service worker script MUST be a separate same-origin file. The
  browser will not accept one inlined, imported from a data: URI, or built at
  runtime. This is the single exception to the single-file rule, and it buys
  exactly one thing — the app opening when there is no network.

  Everything else was already offline: the font is a base64 data: URI, and
  the bank lives in IndexedDB and in a file in a folder you chose. The web
  app manifest is its own small file too — a browser will not accept one
  supplied as a data: URI either — precached below alongside this script.
  The only remaining network call was the request for index.html itself.
  This answers that one.

  NETWORK-FIRST, cache as the fallback.

  The opposite strategy — serve the cache, refresh in the background — is the
  usual advice, and it is wrong here. This app is ONE document with no bundle
  and no version manifest, so a cache-first worker means shipping a fix and
  users never seeing it until some invisible second load. Network-first costs
  nothing when online (the document is fetched exactly as it would have been)
  and gives back precisely what was missing when offline.
*/

const CACHE = 'mcq-mastery-shell-v1';

// The one string that says a page is THIS app and not whatever else answered
// on this port. It lives in index.html's <title>, which is the first thing
// that would differ if the file had been replaced by something else.
const SHELL_MARK = '<title>MCQ Mastery';

// How long a navigation waits on the network before falling back to the
// cached shell, when there is one to fall back to. Long enough that a
// merely slow connection is never mistaken for a dead one: firing too
// eagerly would mean silently serving the previous version of the app for
// a whole session, since nothing here tells anyone an update exists (no
// "Check for an update" control, no updatefound listener). Short enough
// that a captive portal or a connection that has associated but stopped
// forwarding does not leave the page blank for the platform's own fetch
// timeout, which can be a minute or more.
const NAV_RACE_MS = 4000;

self.addEventListener('install', (e) => {
  e.waitUntil((async () => {
    // Warm the cache on the very first visit. Without this the app only
    // survives going offline after it has been loaded a second time, because
    // the first load happens before this worker controls anything — which is
    // exactly the visit where somebody is most likely to shut the laptop and
    // get on a train. A failure here must not fail the installation: the
    // fetch handler fills the same cache on its own.
    try {
      const cache = await caches.open(CACHE);
      await cache.addAll(['./index.html', './manifest.webmanifest']);
    } catch (err) { /* offline at install, or a file that isn't there */ }
    // Take over as soon as possible rather than waiting for every tab to
    // close: there is only ever one document here, and a worker stuck
    // "waiting" is a confusing state to explain to somebody on a train.
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    // CACHE's version suffix has never actually changed, so this deletes
    // nothing today — but it is what turns bumping it, the day this shell
    // ever needs a genuine hard reset, into one that actually clears the
    // previous version's cache instead of leaving it orphaned in Cache
    // Storage forever alongside the new one. (turnOffOffline() in
    // index.html deletes the same mcq-mastery-* caches for the other case:
    // a person switching offline off, not a version change.)
    const names = await caches.keys();
    await Promise.all(names.filter(n => n !== CACHE && n.indexOf('mcq-mastery-') === 0).map(n => caches.delete(n)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  // Only ever GETs, and only ever this origin. Google Drive sync and an
  // external OCR endpoint are both cross-origin and deliberately untouched:
  // caching somebody's API responses is not this worker's business.
  if (req.method !== 'GET') return;
  let url;
  try { url = new URL(req.url); } catch (err) { return; }
  if (url.origin !== self.location.origin) return;

  // Caches a fresh response — but only a real answer (never a 404/500,
  // which would pin a broken page in place for every later offline load)
  // and, for the SHELL specifically, only once confirmed still this app.
  // This worker's scope is the whole origin and it outlives the server
  // that registered it, so anything else that later answers on this port —
  // another project on 8080, a different local server — comes through here
  // too. Cached, that page becomes what opens on a train, from inside an
  // app that can no longer be opened to switch this off. So a navigation
  // only replaces the shell if the page is still this app; both clones are
  // taken before anything reads a body. Always inside waitUntil(), never
  // awaited: a service worker with no pending extend-lifetime promise is
  // free to be killed the instant respondWith()'s own promise settles, and
  // this write can be a slow disk write or — the OCR engine's vendor
  // files — several megabytes, exactly the write that must survive a
  // student closing the tab the moment the page painted. The try/catch is
  // belt-and-braces: a throw from a non-conforming implementation, or a
  // call arriving after the event has already gone inactive, must not
  // reject the response and turn cache bookkeeping into a failed page load.
  const cacheIfShell = (fresh) => {
    if (!(fresh && fresh.ok && fresh.status === 200 && fresh.type !== 'opaque')) return;
    const copy = fresh.clone();
    const keep = req.mode === 'navigate'
      ? fresh.clone().text().then(t => t.indexOf(SHELL_MARK) >= 0, () => false)
      : Promise.resolve(true);
    try {
      e.waitUntil(keep.then(ok => ok && caches.open(CACHE).then(c => c.put(req, copy))).catch(() => { }));
    } catch (err) { /* see comment above */ }
  };

  e.respondWith((async () => {
    try {
      const shell = req.mode === 'navigate' ? ((await caches.match('./index.html')) || (await caches.match('./'))) : null;
      const net = fetch(req);
      // Fire-and-forget: runs whenever net eventually settles, whether or
      // not the race below is still being waited on — the point of racing
      // is never aborting the loser. A rejection here is net's own concern
      // in the catch block below, not this branch's.
      net.then(cacheIfShell, () => { });
      if (!shell) return await net;
      // A cached shell to fall back to is what makes racing worthwhile: a
      // captive portal, or a network that has associated but stopped
      // forwarding, otherwise leaves fetch() pending for the platform's
      // own timeout with the page showing nothing — precisely the
      // situation this cache exists to answer, and precisely the situation
      // a plain "try network, fall back on failure" never detects, because
      // nothing here ever fails; it just never resolves.
      const timeout = new Promise(resolve => setTimeout(() => resolve(shell), NAV_RACE_MS));
      return await Promise.race([net, timeout]);
    } catch (err) {
      const hit = await caches.match(req);
      if (hit) return hit;
      // A navigation with nothing matching — usually "/" against a cached
      // "/index.html", or the other way about. There is only one page in
      // this app, so either is the right answer.
      if (req.mode === 'navigate') {
        const shell = (await caches.match('./index.html')) || (await caches.match('./'));
        if (shell) return shell;
      }
      throw err;
    }
  })());
});
