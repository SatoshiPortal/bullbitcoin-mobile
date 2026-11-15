import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Locales are read from the root catalogue so a 28th language cannot ship
/// without its novlang overrides.
const _repositoryRoot = '../..';
const _rootArbDir = '$_repositoryRoot/localization';
const _novlangArbDir = 'lib/l10n';

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _placeholders(String message) =>
    RegExp(r'\{([A-Za-z_]\w*)\s*[,}]')
        .allMatches(message)
        .map((m) => m.group(1)!)
        .toSet();

String _overrideKey(Map<dynamic, dynamic> e) =>
    '${e['catalogue']}__${e['key']}_${e['store']}';

/// The template (English) messages of a manifest catalogue, read through the
/// l10n.yaml of its package.
Map<String, dynamic> _template(YamlMap catalogue) {
  final dir = '$_repositoryRoot/${catalogue['path']}';
  final l10n = loadYaml(File('$dir/l10n.yaml').readAsStringSync()) as YamlMap;
  return _arb('$dir/${l10n['arb-dir']}/${l10n['template-arb-file']}');
}

void main() {
  final manifest =
      loadYaml(File('manifest.yaml').readAsStringSync()) as YamlMap;
  final entries = (manifest['entries'] as YamlList).cast<YamlMap>().toList();
  final stores = manifest['stores'] as YamlMap;
  final locales = [
    for (final f in Directory(_rootArbDir).listSync().whereType<File>())
      if (RegExp(r'app_[\w]+\.arb$').hasMatch(f.path))
        RegExp(r'app_([\w]+)\.arb$').firstMatch(f.path)!.group(1)!,
  ]..sort();
  final catalogues = manifest['catalogues'] as YamlMap;
  final templates = {
    for (final MapEntry(:key, :value) in catalogues.entries)
      key as String: _template(value as YamlMap),
  };
  String? catalogueText(Map<dynamic, dynamic> e) =>
      templates[e['catalogue']]?[e['key']] as String?;

  test('the main Latin-script languages have their own blacklist', () {
    final apple = (manifest['stores'] as YamlMap)['apple'] as YamlMap;
    final blacklist = apple['blacklist'] as YamlMap;
    for (final language in ['fr', 'es', 'de', 'pt', 'it']) {
      expect(blacklist[language], isNotEmpty, reason: language);
    }
  });

  test('covers the 27 supported languages', () {
    expect(locales, hasLength(27));
    for (final locale in locales) {
      expect(
        File('$_novlangArbDir/novlang_$locale.arb').existsSync(),
        isTrue,
        reason: 'missing novlang_$locale.arb',
      );
    }
    final novlangFiles = Directory(_novlangArbDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .length;
    expect(novlangFiles, locales.length);
  });

  test('declares the root catalogue', () {
    expect(catalogues.keys, contains('app'));
    expect((catalogues['app'] as YamlMap)['path'], '.');
  });

  test('manifest entries are unique and name a known store and catalogue', () {
    final seen = <String>{};
    for (final e in entries) {
      expect(stores.containsKey(e['store']), isTrue, reason: '${e['key']}');
      expect(
        catalogues.containsKey(e['catalogue']),
        isTrue,
        reason: '${e['key']}: unknown catalogue ${e['catalogue']}',
      );
      expect(seen.add(_overrideKey(e)), isTrue, reason: 'dup ${e['key']}');
    }
  });

  test('every manifest key exists in its catalogue with the real word', () {
    for (final e in entries) {
      final text = catalogueText(e);
      expect(
        text,
        isNotNull,
        reason: '${e['catalogue']} catalogue lacks ${e['key']}',
      );
      expect(
        text!.toLowerCase(),
        contains((e['word'] as String).toLowerCase()),
        reason: '${e['key']} must carry the real word "${e['word']}"',
      );
    }
  });

  for (final locale in locales) {
    group('novlang_$locale.arb', () {
      final arb = _arb('$_novlangArbDir/novlang_$locale.arb');
      final messages = arb.keys.where((k) => !k.startsWith('@')).toSet();

      test('has exactly the manifest overrides', () {
        expect(messages, {for (final e in entries) _overrideKey(e)});
      });

      test('keeps the placeholders of the catalogue message', () {
        for (final e in entries) {
          final value = arb[_overrideKey(e)] as String;
          expect(
            _placeholders(value),
            _placeholders(catalogueText(e) ?? ''),
            reason: '${e['key']} in $locale',
          );
        }
      });

      test('never carries a word its store forbids', () {
        final language = locale.split('_').first;
        for (final e in entries) {
          final blacklist =
              (stores[e['store']] as YamlMap)['blacklist'] as YamlMap;
          final words = [
            ...List<String>.from((blacklist['all'] ?? const []) as List),
            ...List<String>.from((blacklist[language] ?? const []) as List),
          ];
          final value = (arb[_overrideKey(e)] as String).toLowerCase();
          for (final word in words) {
            expect(
              value.contains(word),
              isFalse,
              reason: '${e['key']} in $locale contains "$word": $value',
            );
          }
        }
      });
    });
  }
}
