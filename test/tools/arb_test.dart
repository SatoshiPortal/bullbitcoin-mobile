import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// End-to-end tests for `tools/arb.dart`.
///
/// The tool is deliberately not parameterised: it hardcodes the `localization/`
/// directory relative to the current working directory. So rather than import
/// it, each test spins up a throwaway fixture dir with a `localization/` folder
/// and runs the real script as a subprocess with that dir as CWD — exercising
/// exactly the binary a developer/agent invokes. The whole value of the tool is
/// "never corrupt these files", so the load-bearing assertion throughout is the
/// byte-for-byte comparison of untouched content.
void main() {
  // Resolve the script once. The test file lives at test/tools/, the script at
  // tools/arb.dart, both under the repo root.
  final repoRoot = _findRepoRoot();
  final script = p.join(repoRoot, 'tools', 'arb.dart');
  // Under `flutter test`, Platform.resolvedExecutable is the flutter_tester,
  // not a Dart VM — spawning the script against it would hang. Resolve a real
  // Dart binary from the SDK that ships beside it instead.
  final dart = _resolveDart();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('arb_tool_test_');
    Directory(p.join(tmp.path, 'localization')).createSync();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  /// Writes a locale file verbatim and returns its path.
  String writeLocale(String locale, String content) {
    final path = p.join(tmp.path, 'localization', 'app_$locale.arb');
    File(path).writeAsStringSync(content);
    return path;
  }

  String readLocale(String locale) => File(
    p.join(tmp.path, 'localization', 'app_$locale.arb'),
  ).readAsStringSync();

  /// Runs the tool with [args] in the fixture dir. Uses the Dart VM directly
  /// (no `dart run`) so there are no per-call package build hooks — fast and
  /// hermetic.
  ProcessResult run(List<String> args) =>
      Process.runSync(dart, [script, ...args], workingDirectory: tmp.path);

  // A minimal but representative template: a translated key with metadata, a
  // plain key, and a key carrying placeholders — mirroring real .arb shape.
  const enTemplate =
      '{\n'
      '  "@@locale": "en",\n'
      '  "greeting": "Hello",\n'
      '  "@greeting": {\n'
      '    "description": "a greeting"\n'
      '  },\n'
      '  "count": "{n, plural, =1{1 item} other{{n} items}}",\n'
      '  "@count": {\n'
      '    "placeholders": {\n'
      '      "n": {\n'
      '        "type": "int"\n'
      '      }\n'
      '    }\n'
      '  },\n'
      '  "farewell": "Bye"\n'
      '}\n';

  const frTemplate =
      '{\n'
      '  "@@locale": "fr",\n'
      '  "greeting": "Bonjour"\n'
      '}\n';

  group('validate', () {
    test('accepts well-formed files', () {
      writeLocale('en', enTemplate);
      writeLocale('fr', frTemplate);
      final r = run(['validate']);
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(r.stdout, contains('app_en.arb: ok'));
    });

    test('rejects a file whose layout does not match the parsed JSON', () {
      // Valid JSON, but the nested "nested" field is indented at two spaces
      // instead of four — exactly the reflowed-metadata corruption the invariant
      // guards against. It reads as an extra top-level key line, so the line-key
      // count no longer matches the JSON key count and the tool must refuse.
      writeLocale(
        'en',
        '{\n  "@@locale": "en",\n  "a": {\n  "nested": "x"\n  },\n  "b": "2"\n}\n',
      );
      final r = run(['validate']);
      expect(r.exitCode, 1);
    });
  });

  group('add', () {
    test('is byte-identical after a matching delete (round-trip)', () {
      writeLocale('en', enTemplate);
      writeLocale('fr', frTemplate);
      final enBefore = readLocale('en');
      final frBefore = readLocale('fr');

      final add = run([
        'add',
        'newKey',
        '--translations',
        jsonEncode({'en': 'New', 'fr': 'Nouveau'}),
        '--description',
        'brand new',
      ]);
      expect(add.exitCode, 0, reason: add.stderr.toString());
      expect(readLocale('en'), isNot(enBefore));
      expect(readLocale('fr'), isNot(frBefore));

      final del = run(['delete', 'newKey']);
      expect(del.exitCode, 0, reason: del.stderr.toString());
      expect(readLocale('en'), enBefore, reason: 'en not restored byte-exact');
      expect(readLocale('fr'), frBefore, reason: 'fr not restored byte-exact');
    });

    test('produces valid JSON with the new value and metadata', () {
      writeLocale('en', enTemplate);
      run([
        'add',
        'newKey',
        '--translations',
        jsonEncode({'en': 'New'}),
        '--description',
        'brand new',
      ]);
      final map = jsonDecode(readLocale('en')) as Map<String, dynamic>;
      expect(map['newKey'], 'New');
      expect((map['@newKey'] as Map)['description'], 'brand new');
      // The previously-last key must have gained a comma without breaking JSON.
      expect(map['farewell'], 'Bye');
    });

    test('gives the prior last key a comma (no trailing-comma corruption)', () {
      writeLocale('en', enTemplate);
      run([
        'add',
        'newKey',
        '--translations',
        jsonEncode({'en': 'New'}),
      ]);
      final lines = readLocale('en').split('\n');
      final farewell = lines.firstWhere((l) => l.contains('"farewell"'));
      expect(farewell.trimRight().endsWith(','), isTrue);
    });

    test('refuses to overwrite an existing key and writes nothing', () {
      writeLocale('en', enTemplate);
      final before = readLocale('en');
      final r = run([
        'add',
        'greeting',
        '--translations',
        jsonEncode({'en': 'x'}),
      ]);
      // Exit 1 (ArbException): a state conflict, distinct from the exit-64
      // usage errors above (bad key, bad locale, bad placeholder shape).
      expect(r.exitCode, 1);
      expect(readLocale('en'), before);
    });

    test('rejects a non-camelCase key before writing', () {
      writeLocale('en', enTemplate);
      final before = readLocale('en');
      final r = run([
        'add',
        'BadKey',
        '--translations',
        jsonEncode({'en': 'x'}),
      ]);
      expect(r.exitCode, 64);
      expect(readLocale('en'), before);
    });

    test('rejects an unknown locale and leaves all files untouched', () {
      writeLocale('en', enTemplate);
      final before = readLocale('en');
      final r = run([
        'add',
        'newKey',
        '--translations',
        jsonEncode({'en': 'x', 'zz': 'y'}),
      ]);
      expect(r.exitCode, 64);
      expect(readLocale('en'), before);
      expect(
        File(p.join(tmp.path, 'localization', 'app_zz.arb')).existsSync(),
        isFalse,
      );
    });

    test('rejects a malformed placeholder shape', () {
      writeLocale('en', enTemplate);
      final before = readLocale('en');
      final r = run([
        'add',
        'newKey',
        '--translations',
        jsonEncode({'en': 'x'}),
        '--placeholders',
        jsonEncode({'n': 'int'}), // should be {"type":"int"}
      ]);
      expect(r.exitCode, 64);
      expect(readLocale('en'), before);
    });
  });

  group('set', () {
    test('updates an existing locale value in place', () {
      writeLocale('en', enTemplate);
      writeLocale('fr', frTemplate);
      final r = run(['set', 'greeting', 'fr', 'Coucou']);
      expect(r.exitCode, 0, reason: r.stderr.toString());
      final fr = jsonDecode(readLocale('fr')) as Map<String, dynamic>;
      expect(fr['greeting'], 'Coucou');
    });

    test('refuses a key absent from the template', () {
      writeLocale('en', enTemplate);
      writeLocale('fr', frTemplate);
      final before = readLocale('fr');
      final r = run(['set', 'ghost', 'fr', 'x']);
      expect(r.exitCode, 64);
      expect(readLocale('fr'), before);
    });
  });

  group('rename', () {
    test('preserves value and metadata across locales', () {
      writeLocale('en', enTemplate);
      writeLocale('fr', frTemplate);
      final r = run(['rename', 'greeting', 'salutation']);
      expect(r.exitCode, 0, reason: r.stderr.toString());

      final en = jsonDecode(readLocale('en')) as Map<String, dynamic>;
      expect(en.containsKey('greeting'), isFalse);
      expect(en['salutation'], 'Hello');
      expect((en['@salutation'] as Map)['description'], 'a greeting');

      final fr = jsonDecode(readLocale('fr')) as Map<String, dynamic>;
      expect(fr['salutation'], 'Bonjour');
    });

    test('refuses when the new key already exists', () {
      writeLocale('en', enTemplate);
      final before = readLocale('en');
      final r = run(['rename', 'greeting', 'farewell']);
      expect(r.exitCode, 1);
      expect(readLocale('en'), before);
    });
  });

  group('--dry-run', () {
    test('reports intended writes but changes nothing on disk', () {
      writeLocale('en', enTemplate);
      writeLocale('fr', frTemplate);
      final enBefore = readLocale('en');
      final frBefore = readLocale('fr');
      final r = run([
        'add',
        'newKey',
        '--translations',
        jsonEncode({'en': 'New', 'fr': 'Nouveau'}),
        '--dry-run',
      ]);
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(r.stderr, contains('[dry-run]'));
      expect(readLocale('en'), enBefore);
      expect(readLocale('fr'), frBefore);
    });
  });

  group('option validation', () {
    test(
      'rejects an option that is valid globally but wrong for the command',
      () {
        writeLocale('en', enTemplate);
        final r = run(['get', 'greeting', '--description', 'x']);
        expect(r.exitCode, 64);
        expect(r.stderr, contains('Unknown option'));
      },
    );

    test('rejects an outright unknown option', () {
      writeLocale('en', enTemplate);
      final r = run(['missing', '--lst']);
      expect(r.exitCode, 64);
    });
  });
}

/// Finds a real Dart executable to run the script with. `flutter test` sets
/// [Platform.resolvedExecutable] to the flutter_tester, so we look for the
/// `dart` (or `dart.exe`) that ships in the same SDK's `bin/`, walking up from
/// the tester until a `dart-sdk/bin/dart` or a sibling `dart` is found.
String _resolveDart() {
  final exe = Platform.isWindows ? 'dart.exe' : 'dart';
  // 1) Sibling of the resolved executable (covers `dart test`).
  final sibling = p.join(p.dirname(Platform.resolvedExecutable), exe);
  if (File(sibling).existsSync() &&
      p.basenameWithoutExtension(sibling) == 'dart') {
    return sibling;
  }
  // 2) The dart-sdk bundled under a Flutter cache: walk up looking for it.
  var dir = Directory(p.dirname(Platform.resolvedExecutable));
  while (true) {
    final candidate = p.join(dir.path, 'cache', 'dart-sdk', 'bin', exe);
    if (File(candidate).existsSync()) return candidate;
    final nested = p.join(dir.path, 'dart-sdk', 'bin', exe);
    if (File(nested).existsSync()) return nested;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  // 3) Last resort: hope `dart` is on PATH.
  return exe;
}

/// Walks up from this test file to the directory that contains `tools/arb.dart`.
String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'tools', 'arb.dart')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${Directory.current}');
    }
    dir = parent;
  }
}
