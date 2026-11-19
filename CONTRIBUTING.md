# Contributing to Daysteps

Thank you for helping! Daysteps is used by children who rely on routine, so we
favour calm, predictable changes over clever ones.

## Ground rules for the child view

- **Nothing to get lost in.** No menus, dialogs, ads, links or settings in the
  child view. Adult features go behind the lock.
- **Big and clear.** Pictures first, few words, high contrast, large touch
  targets (at least 72 dp for the Done button).
- **Respect calm motion.** Every animation must have a gentle alternative when
  *Calm motion* is on or the system asks for reduced motion.
- **Offline first.** No feature may need the internet, except the optional
  ARASAAC search.

## Setting up

1. Install Flutter **3.50.0** (stable). The exact version CI uses is in
   `.github/workflows/ci.yml`.
2. On Linux, install SQLite for the host tests: `sudo apt-get install libsqlite3-dev`.
3. Get packages and run the tests:

   ```bash
   flutter pub get
   flutter test
   ```

4. Run the app: `flutter run -d chrome` or `flutter run -d <android-device>`.

## Before you open a pull request

```bash
dart format lib test
flutter analyze --fatal-infos
flutter test
```

CI runs the same checks, and also verifies that generated code is up to date.
If you change the database tables in `lib/src/data/database.dart`, regenerate
the code and add a migration (bump `schemaVersion`):

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Pictograms

Bundled symbols must be **CC BY-SA** (or more permissive). ARASAAC
(CC BY-NC-SA) must never be bundled. To add symbols, edit
`tool/symbols/selection.json` and run `node tool/symbols/build_symbols.mjs`
(see `tool/symbols/README.md`).

## Commit messages and releases

Write commit messages in the imperative ("Add …", "Fix …"). Add a line to the
`[Unreleased]` section of `CHANGELOG.md` for anything a parent or teacher would
notice. Maintainers cut releases as described in the README
(“Releases and versioning”).

By contributing you agree that your code is licensed under the GPL-3.0, like
the rest of the project.
