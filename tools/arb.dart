// ignore_for_file: avoid_print
//
// arb.dart — a small utility for managing the app's .arb localization files.
//
// The .arb files under `localization/` are large and easy to corrupt by hand.
// This tool reads and mutates them safely: reads use a JSON parser, and writes
// are surgical line edits that preserve every other byte of the file (so diffs
// stay small and formatting is never churned).
//
// It relies on one invariant that holds for every file in `localization/`:
// each top-level key sits on its own line indented by exactly two spaces, and
// its block runs until the next such line (or the closing brace). The tool
// validates this invariant before mutating and refuses to touch a file that
// breaks it.
//
// Run `dart run tools/arb.dart help` for usage.

import 'dart:convert';
import 'dart:io';

const arbDir = 'localization';
const templateLocale = 'en';

void main(List<String> args) {
  if (args.isEmpty) {
    _printUsage();
    exit(64);
  }

  final command = args.first;
  final rest = args.sublist(1);

  try {
    if (command != 'help' && command != '-h' && command != '--help') {
      _rejectUnknownOptions(command, rest);
    }
    _dryRun = _flag(rest, '--dry-run');
    switch (command) {
      case 'get':
        _cmdGet(rest);
      case 'check':
        _cmdCheck(rest);
      case 'missing':
        _cmdMissing(rest);
      case 'missing-detail':
        _cmdMissingDetail(rest);
      case 'dead':
        _cmdDead(rest);
      case 'add':
        _cmdAdd(rest);
      case 'set':
        _cmdSet(rest);
      case 'fill':
        _cmdFill(rest);
      case 'audit-identical':
        _cmdAuditIdentical(rest);
      case 'audit-placeholders':
        _cmdAuditPlaceholders(rest);
      case 'set-meta':
        _cmdSetMeta(rest);
      case 'rename':
        _cmdRename(rest);
      case 'delete':
        _cmdDelete(rest);
      case 'validate':
        _cmdValidate(rest);
      case 'help':
      case '-h':
      case '--help':
        _printUsage();
      default:
        stderr.writeln('Unknown command: $command\n');
        _printUsage();
        exit(64);
    }
  } on UsageException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(64);
  } on ArbException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

void _cmdGet(List<String> args) {
  final positional = _positional(args);
  if (positional.length != 1) {
    throw UsageException('get expects exactly one KEY argument.');
  }
  final key = positional.first;
  final localeFilter = _option(args, '--locale');

  final locales = localeFilter != null ? [localeFilter] : _allLocales();
  if (localeFilter != null) _requireLocale(localeFilter);

  if (!_isMetaKey(key)) {
    final description = _templateDescription(key);
    if (description != null) print('description: $description');
  }

  var found = false;
  for (final locale in locales) {
    final value = _readMap(_fileFor(locale))[key];
    if (value != null) {
      found = true;
      print('$locale: ${_display(value)}');
    } else if (localeFilter != null) {
      print('$locale: <missing>');
    }
  }
  if (!found && localeFilter == null) {
    throw ArbException('Key "$key" not found in any locale.');
  }
}

void _cmdCheck(List<String> args) {
  final positional = _positional(args);
  if (positional.length != 1) {
    throw UsageException('check expects exactly one KEY argument.');
  }
  final key = positional.first;

  final present = <String>[];
  final missing = <String>[];
  for (final locale in _allLocales()) {
    if (_readMap(_fileFor(locale)).containsKey(key)) {
      present.add(locale);
    } else {
      missing.add(locale);
    }
  }

  final inTemplate = present.contains(templateLocale);
  print('key: $key');
  print('in template ($templateLocale): ${inTemplate ? 'yes' : 'NO'}');
  print('present (${present.length}): ${present.join(', ')}');
  if (missing.isEmpty) {
    print('missing (0): none — fully translated');
  } else {
    print('missing (${missing.length}): ${missing.join(', ')}');
  }
}

void _cmdMissing(List<String> args) {
  final extra = _positional(args);
  if (extra.isNotEmpty) {
    throw UsageException(
      'missing takes no positional arguments; got "${extra.join(' ')}". '
      'To focus on one locale use `missing --locale ${extra.first}`.',
    );
  }
  final localeFilter = _option(args, '--locale');
  final list = _flag(args, '--list');
  if (localeFilter != null) {
    _requireLocale(localeFilter);
    if (localeFilter == templateLocale) {
      throw UsageException(
        'The template locale ("$templateLocale") defines the key set; it '
        'cannot be missing keys relative to itself.',
      );
    }
  }

  final templateKeys = _realKeys(_readMap(_fileFor(templateLocale)));
  final locales = (localeFilter != null ? [localeFilter] : _allLocales())
      .where((l) => l != templateLocale)
      .toList();

  for (final locale in locales) {
    final keys = _readMap(_fileFor(locale)).keys.toSet();
    final missing = templateKeys.where((k) => !keys.contains(k)).toList();
    print('$locale: ${missing.length} missing of ${templateKeys.length}');
    if (list) {
      for (final k in missing) {
        print('  $k');
      }
    }
  }
  if (!list && locales.length > 1) {
    print(
      '\nPass --list to print the missing keys, or --locale <code> to '
      'focus on one locale.',
    );
  }
}

void _cmdMissingDetail(List<String> args) {
  final positional = _positional(args);
  if (positional.length != 1) {
    throw UsageException('missing-detail expects exactly one LOCALE argument.');
  }
  final locale = positional.first;
  _requireLocale(locale);
  if (locale == templateLocale) {
    throw UsageException(
      'The template locale ("$templateLocale") defines the key set; it '
      'cannot be missing keys relative to itself.',
    );
  }

  final template = _readMap(_fileFor(templateLocale));
  final templateKeys = _realKeys(template);
  final localeKeys = _readMap(_fileFor(locale)).keys.toSet();
  final missing = templateKeys.where((k) => !localeKeys.contains(k)).toList();

  final out = <String, dynamic>{};
  for (final key in missing) {
    final meta = template['@$key'];
    out[key] = {
      'en': template[key],
      if (meta is Map && meta['description'] is String)
        'description': meta['description'],
      if (meta is Map && meta['placeholders'] is Map)
        'placeholders': meta['placeholders'],
    };
  }
  print(const JsonEncoder.withIndent('  ').convert(out));
}

void _cmdFill(List<String> args) {
  final positional = _positional(args);
  if (positional.length != 1) {
    throw UsageException('fill expects exactly one LOCALE argument.');
  }
  final locale = positional.first;
  _requireLocale(locale);
  if (locale == templateLocale) {
    throw UsageException(
      'Refusing to bulk-fill the template locale ("$templateLocale") '
      'itself.',
    );
  }

  final translations = _readJsonMapOption(
    args,
    '--translations',
    '--translations-file',
  );
  if (translations == null || translations.isEmpty) {
    throw UsageException(
      'fill requires --translations-file PATH (or --translations '
      '\'{"key":"value",...}\') mapping keys to their translated value.',
    );
  }
  final overwrite = _flag(args, '--overwrite');

  final template = _readMap(_fileFor(templateLocale));
  for (final entry in translations.entries) {
    if (!template.containsKey(entry.key)) {
      throw UsageException(
        'Key "${entry.key}" is not in the "$templateLocale" template. '
        'Add it first with `add` so a getter is generated.',
      );
    }
    if (entry.value is! String) {
      throw UsageException('translation for "${entry.key}" must be a string.');
    }
  }

  final file = _fileFor(locale);
  _assertInvariant(file);
  final existing = _readMap(file);

  final toAppend = <String, dynamic>{};
  final toReplace = <String, dynamic>{};
  final skipped = <String>[];
  for (final entry in translations.entries) {
    if (existing.containsKey(entry.key)) {
      if (overwrite) {
        toReplace[entry.key] = entry.value;
      } else {
        skipped.add(entry.key);
      }
    } else {
      toAppend[entry.key] = entry.value;
    }
  }

  if (toAppend.isNotEmpty) {
    _appendBlocks(file, [
      for (final entry in toAppend.entries)
        _valueBlock(entry.key, entry.value as String),
    ]);
  }
  for (final entry in toReplace.entries) {
    _replaceValue(file, entry.key, entry.value as String);
  }

  print(
    '$locale: added ${toAppend.length}, replaced ${toReplace.length}'
    '${skipped.isNotEmpty ? ', skipped ${skipped.length} (already present, use --overwrite)' : ''}',
  );
  if (skipped.isNotEmpty && _flag(args, '--list')) {
    for (final k in skipped) {
      print('  skipped: $k');
    }
  }
}

void _cmdAuditIdentical(List<String> args) {
  final localeFilter = _option(args, '--locale');
  final list = _flag(args, '--list');
  if (localeFilter != null) _requireLocale(localeFilter);

  final template = _readMap(_fileFor(templateLocale));
  final locales = (localeFilter != null ? [localeFilter] : _allLocales())
      .where((l) => l != templateLocale)
      .toList();

  for (final locale in locales) {
    final map = _readMap(_fileFor(locale));
    final identical = <String>[];
    for (final key in _realKeys(template)) {
      final en = template[key];
      final other = map[key];
      if (other == null) continue; // handled by `missing`
      if (en is String &&
          other is String &&
          en == other &&
          en.trim().isNotEmpty) {
        identical.add(key);
      }
    }
    print('$locale: ${identical.length} values identical to en');
    if (list) {
      for (final k in identical) {
        print('  $k: ${_display(template[k])}');
      }
    }
  }
}

final _identChar = RegExp(r'[a-zA-Z0-9_]');

/// Extracts only the *top-level* `{placeholder}` names from an ARB/ICU value,
/// ignoring anything nested inside a plural/select block. A naive
/// `\{(\w+)\}` regex misidentifies the literal case bodies of
/// `{count, plural, =1{File} other{Files}}` as two extra placeholders named
/// "File" and "Files" — which then never match a translation that actually
/// translates those words, producing a false mismatch on every locale. This
/// walks brace depth instead: a placeholder name is only recorded for a `{`
/// at depth 0, and its whole nested body (case arms, sub-messages, etc.) is
/// then skipped without being scanned for further names.
Set<String> _topLevelPlaceholders(String s) {
  final names = <String>{};
  var i = 0;
  while (i < s.length) {
    if (s[i] != '{') {
      i++;
      continue;
    }
    var j = i + 1;
    while (j < s.length && _identChar.hasMatch(s[j])) {
      j++;
    }
    if (j > i + 1) names.add(s.substring(i + 1, j));
    // Skip to this brace's matching close, ignoring nested identifiers.
    var depth = 1;
    var k = i + 1;
    while (k < s.length && depth > 0) {
      if (s[k] == '{') depth++;
      if (s[k] == '}') depth--;
      k++;
    }
    i = k;
  }
  return names;
}

void _cmdAuditPlaceholders(List<String> args) {
  final localeFilter = _option(args, '--locale');
  final list = _flag(args, '--list');
  if (localeFilter != null) _requireLocale(localeFilter);

  final template = _readMap(_fileFor(templateLocale));
  final locales = (localeFilter != null ? [localeFilter] : _allLocales())
      .where((l) => l != templateLocale)
      .toList();

  for (final locale in locales) {
    final map = _readMap(_fileFor(locale));
    final mismatches = <String>[];
    for (final key in _realKeys(template)) {
      final en = template[key];
      final other = map[key];
      if (en is! String || other is! String) continue;
      final enTokens = _topLevelPlaceholders(en);
      if (enTokens.isEmpty) continue;
      final otherTokens = _topLevelPlaceholders(other);
      if (!enTokens.containsAll(otherTokens) ||
          !otherTokens.containsAll(enTokens)) {
        mismatches.add(key);
      }
    }
    print('$locale: ${mismatches.length} placeholder mismatches');
    if (list) {
      for (final k in mismatches) {
        print('  $k: en=${_display(template[k])} $locale=${_display(map[k])}');
      }
    }
  }
}

void _cmdDead(List<String> args) {
  final extra = _positional(args);
  if (extra.isNotEmpty) {
    throw UsageException(
      'dead takes no positional arguments; got "${extra.join(' ')}". '
      'Use `check <key>` to inspect a single key.',
    );
  }
  final list = _flag(args, '--list');
  final templateKeys = _realKeys(_readMap(_fileFor(templateLocale)));

  final referenced = _referencedTokens();
  final dead = templateKeys.where((k) => !referenced.contains(k)).toList()
    ..sort();

  print(
    '${dead.length} of ${templateKeys.length} template keys look unused '
    'in lib/ and test/ (excluding generated code).',
  );
  print(
    'Heuristic: matches whole-token `.<key>`, `\'<key>\'` or `"<key>"`. '
    'Verify before deleting keys used via dynamic lookup.',
  );
  if (list) {
    for (final k in dead) {
      print(k);
    }
  } else if (dead.isNotEmpty) {
    print('Pass --list to print them.');
  }
}

void _cmdAdd(List<String> args) {
  final positional = _positional(args);
  if (positional.length != 1) {
    throw UsageException('add expects exactly one KEY argument.');
  }
  final key = positional.first;
  _validateKey(key);

  final translations = _readJsonMapOption(
    args,
    '--translations',
    '--translations-file',
  );
  if (translations == null || translations.isEmpty) {
    throw UsageException(
      'add requires --translations \'{"en":"...","fr":"..."}\' '
      '(or --translations-file PATH).',
    );
  }
  if (!translations.containsKey(templateLocale)) {
    throw UsageException(
      'translations must include the "$templateLocale" '
      '(template) value.',
    );
  }
  for (final locale in translations.keys) {
    _requireLocale(locale);
  }
  for (final entry in translations.entries) {
    if (entry.value is! String) {
      throw UsageException('translation for "${entry.key}" must be a string.');
    }
  }

  final description = _option(args, '--description');
  final placeholders = _readJsonMapOption(args, '--placeholders', null);
  if (placeholders != null) _validatePlaceholders(placeholders);

  // Guard: refuse to overwrite an existing key. Also reject a leftover orphan
  // @key (no base key) — appending would create a duplicate @key that then
  // fails _assertInvariant on every later edit. Use `set` or `delete` first.
  for (final locale in translations.keys) {
    final map = _readMap(_fileFor(locale));
    if (map.containsKey(key) || map.containsKey('@$key')) {
      throw ArbException(
        'Key "$key" already exists in $locale. Use `set` to '
        'update a value, or `delete` first to replace it.',
      );
    }
  }

  // Pre-flight every target file so a layout problem aborts before any write,
  // rather than leaving the locale set half-updated.
  final targets = [
    _fileFor(templateLocale),
    ...translations.keys.where((l) => l != templateLocale).map(_fileFor),
  ];
  for (final file in targets) {
    _assertInvariant(file);
  }

  // Template file: value + metadata block.
  _appendBlocks(_fileFor(templateLocale), [
    _valueBlock(key, translations[templateLocale] as String),
    _objectBlock('@$key', _metaMap(description, placeholders)),
  ]);
  print('added $key to $templateLocale (template, with metadata)');

  // Other locales: value only.
  for (final entry in translations.entries) {
    if (entry.key == templateLocale) continue;
    _appendBlocks(_fileFor(entry.key), [
      _valueBlock(key, entry.value as String),
    ]);
    print('added $key to ${entry.key}');
  }

  final translated = translations.keys.toSet();
  final untranslated = _allLocales()
      .where((l) => !translated.contains(l))
      .toList();
  if (untranslated.isNotEmpty) {
    print('\nNot translated yet in: ${untranslated.join(', ')}');
  }
}

void _cmdSet(List<String> args) {
  final positional = _positional(args);
  if (positional.length != 3) {
    throw UsageException('set expects KEY LOCALE VALUE.');
  }
  final key = positional[0];
  final locale = positional[1];
  final value = positional[2];
  _validateKey(key);
  _requireLocale(locale);

  // A locale value with no template key produces an orphan: gen-l10n only
  // generates getters for keys present in the template, so `context.loc.<key>`
  // would never compile. Require the key in the template first.
  if (!_readMap(_fileFor(templateLocale)).containsKey(key)) {
    throw UsageException(
      'Key "$key" is not in the "$templateLocale" template. '
      'Add it first with `add` so a getter is generated.',
    );
  }

  final file = _fileFor(locale);
  if (_readMap(file).containsKey(key)) {
    _replaceValue(file, key, value);
    print('updated $key in $locale');
  } else {
    _appendBlocks(file, [_valueBlock(key, value)]);
    print('added $key to $locale');
  }
}

void _cmdSetMeta(List<String> args) {
  final positional = _positional(args);
  if (positional.length != 1) {
    throw UsageException('set-meta expects exactly one KEY argument.');
  }
  final key = positional.first;
  _validateKey(key);

  final description = _option(args, '--description');
  final placeholders = _readJsonMapOption(args, '--placeholders', null);
  if (description == null && placeholders == null) {
    throw UsageException('set-meta needs --description and/or --placeholders.');
  }
  if (placeholders != null) _validatePlaceholders(placeholders);

  final template = _readMap(_fileFor(templateLocale));
  if (!template.containsKey(key)) {
    throw UsageException(
      'Key "$key" is not in the "$templateLocale" template. Add it with '
      '`add` first.',
    );
  }

  // Merge over existing metadata so unspecified fields (and any custom ARB
  // metadata) survive; only edits the template, never the translations.
  final existing = template['@$key'];
  final meta = <String, dynamic>{
    if (existing is Map) ...existing.cast<String, dynamic>(),
  };
  if (description != null) meta['description'] = description;
  if (placeholders != null && placeholders.isNotEmpty) {
    meta['placeholders'] = placeholders;
  }

  _replaceOrInsertMeta(_fileFor(templateLocale), key, meta);
  print('updated metadata for $key in $templateLocale');
}

void _cmdRename(List<String> args) {
  final positional = _positional(args);
  if (positional.length != 2) {
    throw UsageException('rename expects OLD and NEW key arguments.');
  }
  final oldKey = positional[0];
  final newKey = positional[1];
  _validateKey(oldKey);
  _validateKey(newKey);
  if (oldKey == newKey) {
    throw UsageException('OLD and NEW keys are identical.');
  }

  if (!_readMap(_fileFor(templateLocale)).containsKey(oldKey)) {
    throw ArbException(
      'Key "$oldKey" not found in the "$templateLocale" template.',
    );
  }

  // NEW must be free everywhere, and every file must be well-formed, before we
  // touch anything — a rename must not clobber an existing key or half-apply.
  final files = _allLocales().map(_fileFor).toList();
  for (final file in files) {
    final map = _readMap(file);
    if (map.containsKey(newKey) || map.containsKey('@$newKey')) {
      throw ArbException('Key "$newKey" already exists in ${_basename(file)}.');
    }
    _assertInvariant(file);
  }

  // Renames the key in place on its block's first line, so the value and all
  // metadata are preserved across every locale (no translation loss).
  var renamedIn = 0;
  for (final file in files) {
    final value = _renameKey(file, oldKey, newKey);
    final meta = _renameKey(file, '@$oldKey', '@$newKey');
    if (value || meta) renamedIn++;
  }
  print('renamed $oldKey -> $newKey in $renamedIn file(s)');
}

void _cmdDelete(List<String> args) {
  final positional = _positional(args);
  if (positional.length != 1) {
    throw UsageException('delete expects exactly one KEY argument.');
  }
  final key = positional.first;
  if (_isMetaKey(key)) {
    throw UsageException('Delete the base key; its @metadata is removed too.');
  }

  // Pre-flight every file so a layout problem aborts before any deletion,
  // rather than removing the key from only some locales.
  final files = _allLocales().map(_fileFor).toList();
  for (final file in files) {
    _assertInvariant(file);
  }

  var removedFrom = 0;
  for (final file in files) {
    // Removes both the value key and its @metadata (template only); order is
    // irrelevant since _removeKeys recomputes blocks per key.
    final removed = _removeKeys(file, [key, '@$key']);
    if (removed) removedFrom++;
  }
  if (removedFrom == 0) {
    throw ArbException('Key "$key" not found in any locale.');
  }
  print('deleted $key (and any @$key metadata) from $removedFrom file(s)');
}

void _cmdValidate(List<String> args) {
  final extra = _positional(args);
  if (extra.isNotEmpty) {
    throw UsageException(
      'validate takes no arguments; got "${extra.join(' ')}".',
    );
  }
  var ok = true;
  for (final locale in _allLocales()) {
    final file = _fileFor(locale);
    try {
      final map = _readMap(file);
      _assertInvariant(file);
      print('${_basename(file)}: ok (${map.length} keys)');
    } catch (e) {
      ok = false;
      print('${_basename(file)}: FAILED — $e');
    }
  }
  if (!ok) exit(1);
}

// ---------------------------------------------------------------------------
// File / locale helpers
// ---------------------------------------------------------------------------

List<String> _allLocales() {
  final dir = Directory(arbDir);
  if (!dir.existsSync()) {
    throw ArbException(
      'Localization directory "$arbDir" not found. Run from '
      'the repository root.',
    );
  }
  final locales = <String>[];
  for (final entity in dir.listSync()) {
    if (entity is File) {
      final name = _basename(entity.path);
      final match = RegExp(r'^app_(.+)\.arb$').firstMatch(name);
      if (match != null) locales.add(match.group(1)!);
    }
  }
  locales.sort();
  return locales;
}

String _fileFor(String locale) => '$arbDir/app_$locale.arb';

void _requireLocale(String locale) {
  if (!File(_fileFor(locale)).existsSync()) {
    throw UsageException(
      'Unknown locale "$locale". Valid: '
      '${_allLocales().join(', ')}',
    );
  }
}

// Per-invocation cache of file contents and their parsed maps. A single command
// reads the same large (250–660 KB) file several times — a multi-locale `add`
// hits every locale through _readMap, _assertInvariant and _editLines — so the
// process would otherwise re-read and re-parse each file ~3x. The cache is only
// safe because every write funnels through _editLines, which calls
// _invalidateCache before returning; nothing else mutates a file.
final _rawCache = <String, String>{};
final _mapCache = <String, Map<String, dynamic>>{};

String _readRaw(String file) {
  final cached = _rawCache[file];
  if (cached != null) return cached;
  final f = File(file);
  if (!f.existsSync()) {
    throw ArbException('File not found: $file');
  }
  return _rawCache[file] = f.readAsStringSync();
}

void _invalidateCache(String file) {
  _rawCache.remove(file);
  _mapCache.remove(file);
}

Map<String, dynamic> _readMap(String file) {
  final cached = _mapCache[file];
  if (cached != null) return cached;
  try {
    return _mapCache[file] = jsonDecode(_readRaw(file)) as Map<String, dynamic>;
  } on ArbException {
    rethrow; // file-not-found from _readRaw already has a clean message
  } catch (e) {
    throw ArbException('Invalid JSON in $file: $e');
  }
}

String? _templateDescription(String key) {
  final meta = _readMap(_fileFor(templateLocale))['@$key'];
  if (meta is Map && meta['description'] is String) {
    return meta['description'] as String;
  }
  return null;
}

bool _isMetaKey(String key) => key.startsWith('@');

Set<String> _realKeys(Map<String, dynamic> map) =>
    map.keys.where((k) => !_isMetaKey(k)).toSet();

String _display(Object? value) => value is String ? value : jsonEncode(value);

// ---------------------------------------------------------------------------
// Surgical line editing
// ---------------------------------------------------------------------------

final _topKeyLine = RegExp(r'^  "((?:@@|@)?(?:\\.|[^"\\])*)":');

/// Verifies the two-space-indent invariant this tool relies on for writes.
void _assertInvariant(String file) {
  final lines = _readRaw(file).split('\n');
  final map = _readMap(file);
  final lineKeys = [
    for (final l in lines)
      if (_topKeyLine.firstMatch(l) case final m?) _unescapeKey(m.group(1)!),
  ];
  final mapKeys = map.keys.toList();
  // Count AND order must match the parsed keys. A bare count is not enough: a
  // stray line at 2-space indent (e.g. a reflowed metadata field) can offset
  // one real key and still tie the total, which would make _blocks split a
  // block mid-way and corrupt the following edit.
  if (lineKeys.length != mapKeys.length) {
    throw ArbException(
      '$file does not match the expected 2-space-per-top-level-key layout '
      '(${lineKeys.length} key lines vs ${mapKeys.length} keys). '
      'Refusing to edit.',
    );
  }
  for (var i = 0; i < mapKeys.length; i++) {
    if (lineKeys[i] != mapKeys[i]) {
      throw ArbException(
        '$file does not match the expected layout: key line ${i + 1} reads '
        '"${lineKeys[i]}" but is the ${i + 1}th JSON key "${mapKeys[i]}". '
        'Refusing to edit.',
      );
    }
  }
  // The block model assumes a column-0 closing brace; without it insertion
  // math (closeIdx) would throw a raw RangeError mid-command.
  if (!lines.any((l) => l.trimRight() == '}')) {
    throw ArbException(
      '$file has no top-level closing brace on its own line. Refusing to edit.',
    );
  }
}

class _Block {
  _Block(this.key, this.start, this.end);
  final String key; // top-level key name, incl. @ prefix
  final int start; // inclusive line index
  final int end; // exclusive line index
}

/// Splits the file into ordered top-level key blocks. Line 0 is `{`, the last
/// line is `}`; blocks live strictly between them.
List<_Block> _blocks(List<String> lines) {
  final starts = <int>[];
  final keys = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final m = _topKeyLine.firstMatch(lines[i]);
    if (m != null) {
      starts.add(i);
      keys.add(_unescapeKey(m.group(1)!));
    }
  }
  final closeIdx = lines.lastIndexWhere((l) => l.trimRight() == '}');
  final blocks = <_Block>[];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : closeIdx;
    blocks.add(_Block(keys[i], starts[i], end));
  }
  return blocks;
}

String _unescapeKey(String raw) =>
    jsonDecode('"$raw"') as String; // handles \" etc. in key names

/// Shared write preamble: assert the layout invariant, read the file into its
/// lines (minus the trailing newline), hand them to [edit], and write back only
/// if [edit] reports a change. Returns whether the file was written.
bool _editLines(String file, bool Function(List<String> lines) edit) {
  _assertInvariant(file);
  final lines = _readRaw(file).split('\n');
  final trailingNewline = lines.isNotEmpty && lines.last.isEmpty;
  if (trailingNewline) lines.removeLast();
  final changed = edit(lines);
  if (changed) {
    final result = '${lines.join('\n')}\n';
    // Last-line of defence: the surgical edit math is trusted, but a bug in it
    // must never reach disk. Re-parse before writing so a broken edit aborts
    // cleanly and leaves the file untouched instead of corrupting it.
    try {
      jsonDecode(result);
    } catch (e) {
      throw ArbException(
        'Aborting write to $file: the edit would produce invalid JSON ($e). '
        'This is a bug in the tool; the file was left unchanged.',
      );
    }
    if (_dryRun) {
      stderr.writeln('[dry-run] would write ${_basename(file)}');
    } else {
      File(file).writeAsStringSync(result);
      // Cached raw/map are now stale; drop them so any later read in the same
      // command re-reads the written bytes.
      _invalidateCache(file);
    }
  }
  return changed;
}

void _appendBlocks(String file, List<List<String>> newBlocks) {
  _editLines(file, (lines) {
    final blocks = _blocks(lines);
    final closeIdx = lines.lastIndexWhere((l) => l.trimRight() == '}');

    // Give the current last block a trailing comma (it has none).
    if (blocks.isNotEmpty) {
      final lastLine = blocks.last.end - 1;
      lines[lastLine] = _withComma(lines[lastLine]);
    }

    final insertion = <String>[];
    for (var b = 0; b < newBlocks.length; b++) {
      final block = List<String>.from(newBlocks[b]);
      final isLast = b == newBlocks.length - 1;
      if (!isLast) block[block.length - 1] = _withComma(block.last);
      insertion.addAll(block);
    }

    lines.insertAll(closeIdx, insertion);
    return true;
  });
}

bool _removeKeys(String file, List<String> keys) => _editLines(file, (lines) {
  var changed = false;
  for (final key in keys) {
    final blocks = _blocks(lines);
    final idx = blocks.indexWhere((b) => b.key == key);
    if (idx == -1) continue;
    changed = true;
    final block = blocks[idx];
    final wasLast = idx == blocks.length - 1;
    lines.removeRange(block.start, block.end);
    if (wasLast) {
      // The new last block must not keep a trailing comma.
      final remaining = _blocks(lines);
      if (remaining.isNotEmpty) {
        final lastLine = remaining.last.end - 1;
        lines[lastLine] = _withoutComma(lines[lastLine]);
      }
    }
  }
  return changed;
});

/// Renames a top-level key ([oldKey] → [newKey]) in place, rewriting only the
/// key token on the block's first line so the value/metadata is untouched.
/// Returns false (no write) when [oldKey] is absent.
bool _renameKey(String file, String oldKey, String newKey) =>
    _editLines(file, (lines) {
      final blocks = _blocks(lines);
      final idx = blocks.indexWhere((b) => b.key == oldKey);
      if (idx == -1) return false;
      final start = blocks[idx].start;
      final rest = lines[start].substring(
        _topKeyLine.firstMatch(lines[start])!.end,
      );
      lines[start] = '  ${_jsonString(newKey)}:$rest';
      return true;
    });

void _replaceValue(String file, String key, String value) {
  _editLines(file, (lines) {
    final blocks = _blocks(lines);
    final block = blocks.firstWhere(
      (b) => b.key == key,
      orElse: () => throw ArbException('Key "$key" not found in $file.'),
    );
    if (block.end - block.start != 1) {
      throw ArbException(
        'Value for "$key" in $file spans multiple lines; '
        'refusing to auto-replace.',
      );
    }
    final hadComma = lines[block.start].trimRight().endsWith(',');
    var line = '  ${_jsonString(key)}: ${_jsonString(value)}';
    if (hadComma) line = '$line,';
    lines[block.start] = line;
    return true;
  });
}

String _withComma(String line) {
  final r = line.trimRight();
  return r.endsWith(',') ? line : '$r,';
}

String _withoutComma(String line) {
  final r = line.trimRight();
  return r.endsWith(',') ? r.substring(0, r.length - 1) : line;
}

// ---------------------------------------------------------------------------
// Block builders
// ---------------------------------------------------------------------------

List<String> _valueBlock(String key, String value) => [
  '  ${_jsonString(key)}: ${_jsonString(value)}',
];

Map<String, dynamic> _metaMap(
  String? description,
  Map<String, dynamic>? placeholders,
) => {
  'description': ?description,
  if (placeholders != null && placeholders.isNotEmpty)
    'placeholders': placeholders,
};

/// Renders `"key": <value>` as pretty-printed lines indented one level (two
/// spaces) into the object, matching the surrounding .arb formatting.
List<String> _objectBlock(String key, Object? value) {
  final encoded = const JsonEncoder.withIndent('  ').convert(value);
  final encodedLines = encoded.split('\n');
  final block = <String>[];
  for (var i = 0; i < encodedLines.length; i++) {
    if (i == 0) {
      block.add('  ${_jsonString(key)}: ${encodedLines[i]}');
    } else {
      block.add('  ${encodedLines[i]}');
    }
  }
  return block;
}

/// Replaces the `@key` metadata block in [file], or inserts it right after the
/// base key block when absent. Template-only; never touches translations.
void _replaceOrInsertMeta(String file, String key, Map<String, dynamic> meta) {
  _editLines(file, (lines) {
    final blocks = _blocks(lines);
    final metaBlock = _objectBlock('@$key', meta);
    final metaIdx = blocks.indexWhere((b) => b.key == '@$key');

    if (metaIdx != -1) {
      final old = blocks[metaIdx];
      final hadComma = lines[old.end - 1].trimRight().endsWith(',');
      final replacement = List<String>.from(metaBlock);
      if (hadComma) {
        replacement[replacement.length - 1] = _withComma(replacement.last);
      }
      lines.replaceRange(old.start, old.end, replacement);
    } else {
      final baseIdx = blocks.indexWhere((b) => b.key == key);
      if (baseIdx == -1) {
        throw ArbException('Key "$key" not found in $file.');
      }
      final base = blocks[baseIdx];
      final baseIsLast = baseIdx == blocks.length - 1;
      final insertion = List<String>.from(metaBlock);
      if (baseIsLast) {
        // Base was last (no comma); base now needs one, new meta stays last.
        lines[base.end - 1] = _withComma(lines[base.end - 1]);
      } else {
        // Something follows, so the inserted meta needs a trailing comma too.
        insertion[insertion.length - 1] = _withComma(insertion.last);
      }
      lines.insertAll(base.end, insertion);
    }
    return true;
  });
}

String _jsonString(String value) => jsonEncode(value);

// ---------------------------------------------------------------------------
// Dead-key detection
// ---------------------------------------------------------------------------

/// Collects the identifier tokens the source could reference an l10n key by:
/// member access (`.name`) and bare-identifier string literals (`'name'` /
/// `"name"`). Whole-token by construction, so `send` no longer matches
/// `sendMax`. Scanned per file to avoid buffering the whole codebase at once.
Set<String> _referencedTokens() {
  final tokens = <String>{};
  final memberAccess = RegExp(r'\.([A-Za-z_$][A-Za-z0-9_$]*)');
  final quotedIdent = RegExp('''['"]([A-Za-z_\$][A-Za-z0-9_\$]*)['"]''');
  for (final root in ['lib', 'test']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('lib/generated/')) continue;
      final content = entity.readAsStringSync();
      for (final m in memberAccess.allMatches(content)) {
        tokens.add(m.group(1)!);
      }
      for (final m in quotedIdent.allMatches(content)) {
        tokens.add(m.group(1)!);
      }
    }
  }
  return tokens;
}

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

// Only these are treated as options. Any other token starting with `--` in the
// option region is rejected as an unknown option (so a typo like `--lst` fails
// loudly instead of being silently ignored). To pass a value that genuinely
// starts with `--`, put it after a bare `--`: everything after the separator is
// positional even if it equals a known option/flag name (e.g. `set k en -- --list`).
const _valueOptions = {
  '--locale',
  '--translations',
  '--translations-file',
  '--description',
  '--placeholders',
};
const _booleanFlags = {'--list', '--dry-run', '--overwrite'};

// Which options each command actually accepts. Passing a globally-known option
// that is meaningless for the command (e.g. `get KEY --description x`) is a
// mistake, so it is rejected rather than silently ignored — matching the
// tool's fail-loud stance on typos. Write commands accept `--dry-run`; read
// commands do not (they never write). A command absent from this map takes no
// options at all.
const _commandOptions = <String, Set<String>>{
  'get': {'--locale'},
  'check': {},
  'missing': {'--locale', '--list'},
  'missing-detail': {},
  'dead': {'--list'},
  'add': {
    '--translations',
    '--translations-file',
    '--description',
    '--placeholders',
    '--dry-run',
  },
  'set': {'--dry-run'},
  'fill': {
    '--translations',
    '--translations-file',
    '--overwrite',
    '--list',
    '--dry-run',
  },
  'set-meta': {'--description', '--placeholders', '--dry-run'},
  'rename': {'--dry-run'},
  'delete': {'--dry-run'},
  'validate': {},
  'audit-identical': {'--locale', '--list'},
  'audit-placeholders': {'--locale', '--list'},
};

// Set once in main from the parsed args; read by _editLines to skip the write.
bool _dryRun = false;

/// The slice of [args] before a bare `--` separator (all of it if absent),
/// where option/flag parsing applies.
List<String> _optionArgs(List<String> args) {
  final sep = args.indexOf('--');
  return sep == -1 ? args : args.sublist(0, sep);
}

List<String> _positional(List<String> args) {
  final sep = args.indexOf('--');
  final head = sep == -1 ? args : args.sublist(0, sep);
  final tail = sep == -1 ? const <String>[] : args.sublist(sep + 1);
  final result = <String>[];
  for (var i = 0; i < head.length; i++) {
    final a = head[i];
    if (_valueOptions.contains(a)) {
      if (i + 1 < head.length) i++; // consume the option's value
      continue;
    }
    if (_booleanFlags.contains(a)) continue;
    result.add(a);
  }
  result.addAll(tail); // everything after `--` is positional verbatim
  return result;
}

String? _option(List<String> args, String name) {
  final head = _optionArgs(args);
  final idx = head.indexOf(name);
  if (idx == -1) return null;
  if (idx + 1 >= head.length) {
    throw UsageException('$name requires a value.');
  }
  final value = head[idx + 1];
  if (_valueOptions.contains(value) || _booleanFlags.contains(value)) {
    throw UsageException(
      '$name requires a value; got the option "$value" '
      '(value omitted?).',
    );
  }
  return value;
}

bool _flag(List<String> args, String name) => _optionArgs(args).contains(name);

/// Rejects any `--option` in the option region (before a bare `--`) that the
/// given [command] does not accept, so both a misspelled flag and a valid-but-
/// wrong-command flag fail loudly instead of being silently dropped. Values of
/// known value-options are skipped, so `--description --foo` keeps `--foo` as
/// the description; a literal option-like value goes after the `--` separator.
void _rejectUnknownOptions(String command, List<String> args) {
  final allowed = _commandOptions[command] ?? const <String>{};
  final head = _optionArgs(args);
  for (var i = 0; i < head.length; i++) {
    final a = head[i];
    if (allowed.contains(a) && _valueOptions.contains(a)) {
      i++; // skip this option's value, whatever it is
      continue;
    }
    if (allowed.contains(a)) continue; // a boolean flag valid for this command
    if (a.startsWith('--')) {
      final known = allowed.toList()..sort();
      final valid = known.isEmpty
          ? '$command takes no options'
          : 'Valid for $command: ${known.join(', ')}';
      throw UsageException(
        'Unknown option "$a" for $command. $valid. To pass a '
        'value that begins with "--", put it after a bare "--".',
      );
    }
  }
}

// gen-l10n requires resource names to be lowerCamelCase (a valid Dart method
// name starting with a lowercase letter).
final _keyPattern = RegExp(r'^[a-z][a-zA-Z0-9_]*$');

/// Each ARB placeholder must map to an object (`{"type":"int"}`), not a bare
/// value. Checking here turns an abbreviated shape into a clear error instead
/// of a much later, context-free failure inside `make translations`.
void _validatePlaceholders(Map<String, dynamic> placeholders) {
  for (final entry in placeholders.entries) {
    if (entry.value is! Map) {
      throw UsageException(
        'Placeholder "${entry.key}" must map to an object like {"type":"int"}, '
        'got ${entry.value.runtimeType}. '
        'Example: --placeholders \'{"count":{"type":"int"}}\'.',
      );
    }
  }
}

/// Rejects keys gen-l10n cannot turn into a Dart getter, before anything is
/// written (a bad key would otherwise only fail later in `make translations`).
void _validateKey(String key) {
  if (!_keyPattern.hasMatch(key)) {
    throw UsageException(
      'Invalid key "$key". Must be lowerCamelCase (start with a lowercase '
      'letter; letters, digits, underscore only).',
    );
  }
}

/// Like [_readJsonOption] but guarantees the result is a JSON object, turning a
/// non-object payload into a clean UsageException instead of a CastError.
Map<String, dynamic>? _readJsonMapOption(
  List<String> args,
  String inlineName,
  String? fileName,
) {
  final decoded = _readJsonOption(args, inlineName, fileName);
  if (decoded == null) return null;
  if (decoded is! Map<String, dynamic>) {
    throw UsageException(
      '$inlineName must be a JSON object, got '
      '${decoded.runtimeType}.',
    );
  }
  return decoded;
}

Object? _readJsonOption(
  List<String> args,
  String inlineName,
  String? fileName,
) {
  final inline = _option(args, inlineName);
  final path = fileName != null ? _option(args, fileName) : null;
  String? raw;
  if (inline != null) {
    raw = inline;
  } else if (path != null) {
    final f = File(path);
    if (!f.existsSync()) throw UsageException('File not found: $path');
    raw = f.readAsStringSync();
  }
  if (raw == null) return null;
  try {
    return jsonDecode(raw);
  } catch (e) {
    throw UsageException('Invalid JSON for $inlineName: $e');
  }
}

String _basename(String path) => path.split('/').last;

// ---------------------------------------------------------------------------
// Errors & usage
// ---------------------------------------------------------------------------

class UsageException implements Exception {
  UsageException(this.message);
  final String message;
}

class ArbException implements Exception {
  ArbException(this.message);
  final String message;
}

void _printUsage() {
  print(r'''
arb.dart — manage the .arb localization files under localization/

Usage: dart run tools/arb.dart <command> [args]

Read commands:
  get KEY [--locale L]
      Print the description and the value of KEY across all locales
      (or just one with --locale).

  check KEY
      Show which locales have KEY and which are missing it.

  missing [--locale L] [--list]
      Report keys present in the template (en) but missing per locale.
      --locale focuses on one locale; --list prints the missing keys.

  missing-detail LOCALE
      Print a JSON object {key: {en, description, placeholders}} for every
      key missing in LOCALE — feed straight to a translator, then to `fill`.

  audit-identical [--locale L] [--list]
      Report values that are byte-identical to the en template — a likely
      untranslated / copy-pasted string (some overlap, e.g. brand names or
      numbers, is expected and not itself a bug).

  audit-placeholders [--locale L] [--list]
      Report values whose {placeholder} tokens don't match the en template's
      (missing, extra, or renamed) — a near-certain translation bug since a
      missing placeholder silently drops data at render time.

  dead [--list]
      List template keys with no apparent reference in lib/ or test/
      (heuristic).

  validate
      Parse every .arb file and confirm the 2-space layout invariant.

Write commands (surgical; other keys are left byte-for-byte unchanged):
  add KEY --translations '{"en":"...","fr":"..."}'
          [--translations-file PATH] [--description TEXT]
          [--placeholders '{"count":{"type":"int"}}']
      Add a new key. The "en" value is required and goes to the template
      along with its metadata; each other locale gets its value.

  set KEY LOCALE VALUE
      Set or update the value of KEY for a single locale. KEY must already
      exist in the template.

  fill LOCALE --translations-file PATH [--overwrite]
      Bulk-add many key/value translations to one locale in a single pass
      (PATH is a JSON object {"key":"value",...}, as produced — after
      translation — from `missing-detail`). Keys already present in LOCALE
      are left untouched unless --overwrite is given.

  set-meta KEY [--description TEXT] [--placeholders '{...}']
      Update the template metadata (description / placeholders) of an existing
      KEY in place, without touching any translation.

  rename OLD NEW
      Rename a key across every locale in place, preserving all values and
      metadata (NEW must not already exist).

  delete KEY
      Remove KEY (and its @KEY metadata) from every locale file.

Every write command accepts --dry-run: it runs all checks and reports which
files would change, without writing anything.

A value that looks like an option (e.g. the literal "--list") can be passed
after a bare `--`: `set KEY LOCALE -- --list`.

Examples:
  dart run tools/arb.dart get exchangeTestnetBasicAuthTitle
  dart run tools/arb.dart check exchangeTestnetBasicAuthTitle
  dart run tools/arb.dart missing --locale fr --list
  dart run tools/arb.dart dead --list
  dart run tools/arb.dart add myNewKey \
    --translations '{"en":"Hello","fr":"Bonjour"}' \
    --description "A greeting"
  dart run tools/arb.dart delete myNewKey
''');
}
