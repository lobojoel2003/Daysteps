# Web files

- `index.html`, `manifest.json`, `icons/`, `favicon.png` — the installable web app shell.
- `flutter_bootstrap.js` — starts Flutter without its deprecated service worker.
- `sw.js` — Daysteps' own service worker, so the app works offline after the
  first visit. `tool/web/finalize_build.py` stamps it with a build id.
- `sqlite3.wasm` and `drift_worker.js` — SQLite for the browser, used by
  [drift](https://drift.simonbinder.eu/platforms/web/). They must match the
  `sqlite3` and `drift` package versions in `pubspec.lock`; refresh them with
  `tool/web/update_sqlite_assets.sh` after upgrading those packages.
