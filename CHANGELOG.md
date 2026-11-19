# Changelog

All notable changes to Daysteps are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
Daysteps uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Each
release is a git tag `vMAJOR.MINOR.PATCH`; the Android build number (versionCode)
is the number after `+` in `pubspec.yaml` and goes up with every release.

## [Unreleased]

## [1.0.1] - 2026-11-19

### Changed

- Smaller Android downloads: native libraries are now compressed inside the
  APKs.
- Release notes recommend the APK that suits most devices first.

## [1.0.0] - 2026-11-19

The first release: picture schedules, first–then boards and visual timers that
work offline on Android and in the browser.

### Added

- **Child view** with almost nothing on it: the current step large and
  highlighted, the next step beside it, a row of all steps with finished ones
  ticked, and one big green **Done** button.
- A satisfying **done animation** (a tick that pops and a burst of confetti) and
  an **All done!** celebration at the end. *Calm motion* swaps them for gentle
  fades.
- **First–then boards**: "first homework, then tablet".
- **Visual timers** that shrink as a coloured disc, either sweeping like a clock
  hand or shrinking towards the middle. Add a timer to any step, or start a
  quick full-screen timer from the home screen.
- **Adult lock**: press and hold the lock in the corner for two seconds, then
  answer a sum, to leave the child view. The back button does nothing, the
  screen stays awake and Android hides the system bars.
- **Drag-and-drop editor**: reorder steps by dragging; on tablets and
  computers drag pictures straight from the library onto the board.
- **179 bundled pictograms** from Mulberry Symbols and OpenMoji (CC BY-SA 4.0),
  searchable and grouped into nine categories.
- **Family photos**: take a photo or pick one from the gallery to use on a card.
- **Optional ARASAAC downloads**: search the ARASAAC catalogue online and keep
  individual pictograms on the device. They are not bundled because their
  licence (CC BY-NC-SA 4.0) forbids commercial use.
- **Text-to-speech** with the device's own voice: tap a card to hear it.
- **Sharing between devices**: as a `.daysteps` file (photos included), or as
  a QR code / link that any phone camera can open in the web app.
- **Back up and restore** all boards in one file.
- Four **example boards** (Morning, After school, Bedtime, and Homework then
  tablet) so the app is useful straight away.
- **Offline web app** that can be installed from the browser.
- No account, no ads, no tracking.

[Unreleased]: https://github.com/lobojoel2003/Daysteps/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/lobojoel2003/Daysteps/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/lobojoel2003/Daysteps/releases/tag/v1.0.0
