// Bumps the app version in pubspec.yaml and dates the CHANGELOG.
//
//   dart run tool/bump_version.dart patch      # 1.0.0+1 -> 1.0.1+2
//   dart run tool/bump_version.dart minor      # 1.0.1+2 -> 1.1.0+3
//   dart run tool/bump_version.dart major      # 1.1.0+3 -> 2.0.0+4
//   dart run tool/bump_version.dart build      # 2.0.0+4 -> 2.0.0+5 (rebuild)
//   dart run tool/bump_version.dart minor --pre=beta.1   # 1.1.0-beta.1+3
//
// The build number (after "+") is Android's versionCode, so it goes up by one
// on every bump and never goes back down. Notes under "## [Unreleased]" in
// CHANGELOG.md move to a new section for the version.
//
// ignore_for_file: avoid_print
import 'dart:io';

final _version = RegExp(
  r'^version:\s*(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?\+(\d+)\s*$',
  multiLine: true,
);

const _repo = 'https://github.com/lobojoel2003/Daysteps';

void main(List<String> args) {
  final part = args.where((a) => !a.startsWith('--')).firstOrNull;
  final pre = args
      .where((a) => a.startsWith('--pre='))
      .map((a) => a.substring(6))
      .firstOrNull;
  if (!{'major', 'minor', 'patch', 'build'}.contains(part)) {
    stderr.writeln(
      'Usage: dart run tool/bump_version.dart <major|minor|patch|build> [--pre=beta.1]',
    );
    exit(64);
  }

  final pubspecFile = File('pubspec.yaml');
  final pubspec = pubspecFile.readAsStringSync();
  final match = _version.firstMatch(pubspec);
  if (match == null) {
    stderr.writeln('Could not find "version: X.Y.Z+N" in pubspec.yaml');
    exit(1);
  }

  var major = int.parse(match[1]!);
  var minor = int.parse(match[2]!);
  var patch = int.parse(match[3]!);
  final oldPre = match[4];
  final build = int.parse(match[5]!) + 1;
  final oldName = '$major.$minor.$patch${oldPre == null ? '' : '-$oldPre'}';

  switch (part) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
    case 'minor':
      minor++;
      patch = 0;
    case 'patch':
      // 1.2.0-beta.1 -> 1.2.0 finishes a pre-release instead of skipping it.
      if (oldPre == null) patch++;
    case 'build':
      break;
  }
  final keepPre = part == 'build' ? oldPre : null;
  final suffix = pre ?? keepPre;
  final name = '$major.$minor.$patch${suffix == null ? '' : '-$suffix'}';

  pubspecFile.writeAsStringSync(
    pubspec.replaceFirst(_version, 'version: $name+$build'),
  );
  print('pubspec.yaml: $oldName+${build - 1} -> $name+$build');

  if (name != oldName) _updateChangelog(name);

  print('''

Next steps:
  1. Review CHANGELOG.md (notes for $name).
  2. git commit -am "Release v$name"
  3. git tag -a v$name -m "Daysteps $name"
  4. git push origin main --follow-tags
The Release workflow then builds and publishes v$name.''');
}

void _updateChangelog(String version) {
  final file = File('CHANGELOG.md');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  if (text.contains('## [$version]')) {
    print('CHANGELOG.md already has a section for $version');
    return;
  }
  final date = DateTime.now().toIso8601String().substring(0, 10);
  text = text.replaceFirst(
    '## [Unreleased]',
    '## [Unreleased]\n\n## [$version] - $date',
  );

  // Update the comparison links at the bottom.
  final previous = RegExp(
    r'^\[Unreleased\]: .*/compare/v(.+)\.\.\.HEAD$',
    multiLine: true,
  ).firstMatch(text)?[1];
  text = text.replaceFirst(
    RegExp(r'^\[Unreleased\]: .*$', multiLine: true),
    '[Unreleased]: $_repo/compare/v$version...HEAD\n'
    '[$version]: $_repo/compare/v${previous ?? version}...v$version',
  );
  file.writeAsStringSync(text);
  print('CHANGELOG.md: added section [$version] - $date');
}
