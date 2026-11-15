import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// A workspace member is reached only through the libraries directly under its
// lib/: the analyzer's implementation_imports lint covers lib/src only, so an
// import of any other nested file (lib/data/..., lib/domain/...) would pass
// unnoticed. No member imports the app.

/// Pre-existing imports of a non-exported file, to fix in their own change.
const _knownExceptions = {
  // ExternalTorPort is not exported by bull_tor's public libraries.
  'test/core_test/recoverbull/ensure_recoverbull_tor_session_usecase_test.dart':
      'package:bull_tor/src/domain/ports/external_tor_port.dart',
  'test/features/wallet/domain/get_external_tor_proxy_status_usecase_test.dart':
      'package:bull_tor/src/domain/ports/external_tor_port.dart',
};

final _directive = RegExp(r'^\s*(?:import|export)\s+[^;]+;', multiLine: true);
final _packageUri = RegExp(r'''['"]package:([a-z0-9_]+)/([^'"]+)['"]''');

Iterable<RegExpMatch> _packageImports(String source) => _directive
    .allMatches(source)
    .expand((directive) => _packageUri.allMatches(directive.group(0) ?? ''));

Map<String, String> _workspaceMembers() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final start = lines.indexWhere((line) => line.startsWith('workspace:'));
  final members = <String, String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final directory = RegExp(r'^\s+-\s+(\S+)\s*$').firstMatch(line)?.group(1);
    if (directory == null) break;
    final name = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(File('$directory/pubspec.yaml').readAsStringSync())?.group(1);
    if (name == null) fail('$directory/pubspec.yaml has no name');
    members[name] = directory;
  }
  return members;
}

void main() {
  test('conditional import and export URIs are included', () {
    const source =
        "import 'stub.dart' if (dart.library.io) 'package:bb_mobile/app.dart';\n"
        "export 'package:primitives/primitives.dart' if (dart.library.io) 'package:bb_mobile/init.dart';";
    expect(_packageImports(source).map((match) => match.group(1)), [
      'bb_mobile',
      'primitives',
      'bb_mobile',
    ]);
  });
  test(
    'workspace members are imported only through their public libraries',
    () {
      final members = _workspaceMembers();
      expect(members, isNotEmpty);
      final violations = <String>[];
      final files =
          Process.runSync('git', [
                'ls-files',
                '--cached',
                '--others',
                '--exclude-standard',
                '*.dart',
              ]).stdout
              .toString()
              .split('\n')
              .where((path) => path.isNotEmpty && File(path).existsSync());
      for (final path in files) {
        final owner = members.entries
            .where((member) => path.startsWith('${member.value}/'))
            .map((member) => member.key)
            .firstOrNull;
        for (final match in _packageImports(File(path).readAsStringSync())) {
          final package = match.group(1);
          final libraryPath = match.group(2) ?? '';
          final uri = 'package:$package/$libraryPath';
          final crossesMember =
              members.containsKey(package) &&
              package != owner &&
              libraryPath.contains('/');
          final importsApp = owner != null && package == 'bb_mobile';
          if ((crossesMember || importsApp) && _knownExceptions[path] != uri) {
            violations.add('$path: $uri');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
