import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

/// The package's custody invariants, as assertions rather than prose.
///
/// Auditing this package should not mean reading it. These tests read `lib/` and check what a reviewer would otherwise have to establish by hand; the frozen on-disk format is pinned by `secret_model_golden_test.dart`.
///
/// They are tripwires, not proofs: they read source text, so a sufficiently creative violation slips past. What they catch is the ordinary way these break — someone adding an operation, a failure or an export without noticing what it costs.
void main() {
  final lib = Directory('lib');
  final sources = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  String read(String path) => File(path).readAsStringSync();

  /// `lib/src/<module>/…` → the module; `lib/secrets.dart` → null. The
  /// package barrel belongs to no module, so every `src/` import it makes
  /// must be a module entry point.
  String? moduleOf(File file) {
    final parts = file.path.split('/');
    return parts.length >= 4 && parts[1] == 'src' ? parts[2] : null;
  }

  /// Strips `///` and `//` so a name mentioned in prose is not a hit.
  String code(String source) => source
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('every SecretFailure is constructed in the data layer', () {
    // The boundary carries the two rules that matter — a sealed keystore is never an absence, and no foreign message travels — so a failure built anywhere else bypasses both. `public/` in particular constructs none: it forwards `Result`s (AGENTS.md, rule 11).
    final failures = RegExp(r'final class (\w+Failure) extends SecretFailure')
        .allMatches(read('lib/src/domain/failures.dart'))
        .map((m) => m.group(1)!)
        .toList();
    expect(failures, isNotEmpty, reason: 'no failures found to check');

    const allowed = {
      'lib/src/domain/failures.dart', // declarations
      'lib/src/data/boundary.dart', // exception → failure, the one try/catch
      'lib/src/data/secret_repository.dart', // the two that are not exceptions: not-found, mnemonic required
      'lib/src/data/database_key_repository.dart', // not-found on an open-only read
    };

    final offenders = <String>[];
    for (final file in sources) {
      if (allowed.contains(file.path)) continue;
      final body = code(file.readAsStringSync());
      for (final failure in failures) {
        // `Name(` is a construction. `Name.new` (a reference handed to
        // the boundary) and `Name` in a type position are not.
        if (RegExp('\\b$failure\\(').hasMatch(body)) {
          offenders.add('${file.path}: $failure(');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the fluent sugar cannot do anything', () {
    // `secret.sign.psbt(…)` must be exactly `secret.signPsbt(…)`. If the
    // sugar could hold behaviour, the flat class would stop being the
    // whole audit surface.
    final body = code(read('lib/src/public/extensions.dart'));

    for (final forbidden in [
      'await ', 'async', 'guard(', 'log.',
      '_repository', '_deriver', '_signer',
      'SecretMaterial', 'MnemonicMaterial', 'SeedMaterial',
      'return ', // every member is a single arrow expression
    ]) {
      expect(
        body.contains(forbidden),
        isFalse,
        reason: 'extensions.dart must not contain "$forbidden"',
      );
    }

    // Every member forwards to the representation object and nothing
    // else: as many `_secret.` as there are member bodies.
    final arrows = '=>'.allMatches(body).length;
    final forwards = '_secret'.allMatches(body).length;
    expect(forwards, greaterThanOrEqualTo(arrows));
  });

  test('cross-module imports go through the module entry point', () {
    // Dart has no directory-level visibility, so this is what makes
    // "one file per module fronts the others" a rule rather than a
    // habit: `public/` may import `crypto/crypto.dart`; if it reaches for
    // `crypto/signers/bitcoin_signer.dart`, this fails. Inside a module,
    // files import each other freely — that is the implementation.
    const modules = {'public', 'crypto', 'data', 'domain'};
    final offenders = <String>[];
    for (final file in sources) {
      final mine = moduleOf(file);
      for (final m in RegExp(
        r"import 'package:secrets/src/([^']+)'",
      ).allMatches(code(file.readAsStringSync()))) {
        final path = m.group(1)!;
        final target = path.split('/').first;
        if (target == mine || !modules.contains(target)) continue;
        if (path != '$target/$target.dart') {
          offenders.add('${file.path} → $path');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('foreign dependencies are confined to the module that owns them', () {
    // Where the FFI is, is the first thing a reviewer of a custody
    // package asks. `crypto/` owns bdk, lwk, boltz and recoverbull;
    // `data/` owns the keystore; `domain/` owns nothing foreign — it is
    // the part that needs no device to be verified; `public/` orchestrates
    // and computes nothing.
    const owner = {
      'bull_sdk': 'crypto',
      'recoverbull': 'crypto',
      'flutter_secure_storage': 'data',
    };
    const domainMayImport = {'primitives', 'meta', 'convert', 'secrets'};

    final offenders = <String>[];
    for (final file in sources) {
      final mine = moduleOf(file);
      final imports = RegExp(
        r"import 'package:([a-z_0-9]+)",
      ).allMatches(code(file.readAsStringSync())).map((m) => m.group(1)!);
      for (final dep in imports) {
        final allowed = owner[dep];
        if (allowed != null && mine != allowed) {
          offenders.add('${file.path} imports $dep (belongs to $allowed/)');
        }
        if (mine == 'domain' && !domainMayImport.contains(dep)) {
          offenders.add('${file.path} imports $dep (domain/ must stay pure)');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the public surface is exactly what is declared here', () {
    // The barrel `show`s some files and re-exports others whole, so a name can become public two levels down. This walks the export graph and compares it to a literal list: adding an export is a diff in this test, with its reason in review.
    Set<String> surfaceOf(String path) {
      final source = code(File(path).readAsStringSync());
      final names = <String>{};

      final declaration = RegExp(
        r'\n(?:final |base |sealed |abstract |interface |mixin )*'
        r'(?:class|enum|extension type|typedef|mixin)\s+(\w+)',
      );
      for (final m in declaration.allMatches(source)) {
        if (!m.group(1)!.startsWith('_')) names.add(m.group(1)!);
      }

      final export = RegExp("export\\s+'([^']+)'(?:\\s+show\\s+([^;]+))?;");
      for (final m in export.allMatches(source)) {
        final shown = m.group(2);
        if (shown != null) {
          names.addAll(
            shown.split(',').map((n) => n.trim()).where((n) => n.isNotEmpty),
          );
          continue;
        }
        names.addAll(
          surfaceOf('lib/${m.group(1)!.replaceFirst('package:secrets/', '')}'),
        );
      }
      return names;
    }

    // Every name a consumer can write after `import 'package:secrets/secrets.dart'`.
    const declared = {
      // lifecycle and handle
      'Secrets', 'Secret', 'RestoredVault',
      // the grouped spelling: forwards, holds nothing
      'SecretFluent', 'SecretDerivation', 'SecretDescriptors', 'SecretBip85',
      'SecretSigning', 'SecretBackup',
      // the passphrase caveat, as a type a caller must switch on
      'PassphraseScope', 'WholeSecret', 'WordsOnly',
      // sealed display: the only way words reach a screen
      'MnemonicView', 'MnemonicChallenge', 'MnemonicTile',
      // what operations hand back
      'Descriptors', 'PsbtSigner',
      'SwapKey', 'EncryptedVault', 'DatabaseKey', 'SecretInfo', 'SecretKind',
      'SecretListing',
      // the failure family
      'SecretFailure', 'SecretNotFoundFailure', 'SecretFetchFailure',
      'SecretStoreFailure', 'SecretDeleteFailure', 'SecretStoreLockedFailure',
      'DatabaseKeyCorruptFailure', 'MnemonicRequiredFailure',
      'InvalidMnemonicFailure', 'InvalidVaultFailure',
      'UnsupportedNetworkFailure', 'SecretIdentityMismatchFailure',
      'SecretDerivationFailure',
    };

    expect(surfaceOf('lib/secrets.dart'), declared);
  });

  test('the passphrase caveat has one author', () {
    // Three outputs derive from the words alone; whether one is `WordsOnly` must not be decided three times. `SecretInfo.scope` decides it, which is also what lets `liquidDescriptor` — FFI-bound, so not unit-testable — be covered by the same line as `backupVault`, which is.
    final built = RegExp(r'\b(WordsOnly|WholeSecret)\(');

    expect(
      built.allMatches(code(read('lib/src/domain/secret_info.dart'))),
      hasLength(2),
      reason: 'both variants are constructed in SecretInfo.scope',
    );

    const mayInvert = 'lib/src/public/secrets.dart'; // see restoreVault
    for (final file in sources) {
      if (file.path == 'lib/src/domain/secret_info.dart') continue;
      if (file.path == 'lib/src/domain/passphrase_scope.dart') continue;
      if (file.path == mayInvert) continue;
      expect(
        built.hasMatch(code(file.readAsStringSync())),
        isFalse,
        reason: '${file.path} decides the passphrase caveat on its own',
      );
    }
  });

  test('the stored mnemonic has no exit: revealWords is @internal', () {
    // The README promises it; removing the annotation would otherwise pass
    // green. `@internal` is what turns a feature reaching for the words
    // into an analyzer error, so it is the seal, not the documentation of one.
    final body = code(read('lib/src/public/secret.dart'));
    expect(
      RegExp(
        r'@internal\s+Future<Result<RevealedMnemonic, SecretFailure>>\s+revealWords\(',
      ).hasMatch(body),
      isTrue,
      reason: 'revealWords must be annotated @internal',
    );
    expect(
      code(read('lib/src/public/extensions.dart')),
      isNot(contains('revealWords')),
      reason: 'the sugar must not re-export the exit',
    );
  });

  test('the sealed widgets hand out widgets, never a word', () {
    // A1 (Codex, 2026-09-16): a builder that receives `String word` lets a
    // `Map<int, String>` in the callback rebuild the mnemonic — no import of
    // internals needed. So the host gets a `SealedWord`, whose text has no
    // accessor, and this holds the signatures to it.
    final view = code(read('lib/src/public/mnemonic_view.dart'));
    final challenge = code(read('lib/src/public/mnemonic_challenge.dart'));
    final sealed = code(read('lib/src/public/sealed_word.dart'));

    expect(
      RegExp(
        r'Function\(BuildContext context, int number, Widget word\)',
      ).hasMatch(view),
      isTrue,
      reason: 'wordBuilder must receive the word as a widget',
    );
    expect(view, isNot(contains('String word')));
    expect(
      RegExp(r'final Widget word;').hasMatch(challenge),
      isTrue,
      reason: 'MnemonicTile.word must be a widget',
    );
    expect(challenge, isNot(contains('final String word')));
    // And the widget itself exposes nothing: private fields, no getter.
    expect(sealed, contains('final String _word;'));
    expect(RegExp(r'String get \w+').hasMatch(sealed), isFalse);
    // Not part of the surface — it is the seal, not an API.
    expect(read('lib/secrets.dart'), isNot(contains('sealed_word')));
  });

  test('every operation on Secret is inventoried', () {
    // `Secret` is the audit surface: nothing appears on it unlisted. The verdict matters more than the return type — `bip85Hex` hands back entropy in a `String`, which a type-name filter misses.
    const inventory = {
      // derived: public keys, descriptors, signatures, a verdict
      'xpub': 'derived',
      'liquidXpub': 'derived',
      'bitcoinDescriptors': 'derived',
      'liquidDescriptor': 'derived',
      'signPsbt': 'derived',
      'signPset': 'derived',
      'verifyWords': 'derived',
      // material by design: children this feature was asked to create, for use elsewhere
      'bip85Hex': 'material',
      'bip85Mnemonic': 'material',
      'swapKey': 'material',
      // material: the stored secret itself, and `@internal` — only the
      // package's own sealed widgets may call it
      'revealWords': 'material',
      // a signing capability, not data
      'psbtSigner': 'capability',
      // ciphertext plus the key that opens it
      'backupVault': 'ciphertext',
    };

    // Every public member of `Secret`, whatever it returns. M2 (Codex,
    // 2026-09-16): matching `Future<Result<…>>` alone let a
    // `Future<String> exportMnemonic()` through all seven invariants. So
    // this reads each declaration at class-body indentation and keeps the
    // ones that are not the constructor, the handle's two values, or
    // `toString`; anything else must be inventoried with a verdict.
    // Read as Dart, not as text. Two regexes in a row let a
    // `Future<String>` and then a `dynamic exportMnemonic()` through
    // (Codex, M2/M3, 2026-09-16/17); the AST has no such blind spot. Every
    // member of `Secret` that is not the constructor, the handle's two values
    // or `toString` is an operation: inventoried, with a verdict, returning
    // `Future<Result<…, SecretFailure>>`.
    final unit = parseString(
      content: File('lib/src/public/secret.dart').readAsStringSync(),
      path: 'lib/src/public/secret.dart',
    ).unit;
    final secretClass = unit.declarations
        .whereType<ClassDeclaration>()
        .singleWhere((c) => c.namePart.typeName.lexeme == 'Secret');
    final members = switch (secretClass.body) {
      BlockClassBody(:final members) => members,
      EmptyClassBody() => const <ClassMember>[],
    };

    final operations = <String, String>{};
    final others = <String>[];
    for (final member in members) {
      switch (member) {
        case ConstructorDeclaration():
          continue;
        case FieldDeclaration(:final fields):
          for (final v in fields.variables) {
            final field = v.name.lexeme;
            if (field.startsWith('_') || field == 'info') continue;
            others.add('field $field');
          }
        case MethodDeclaration(:final name, :final returnType, :final isGetter):
          if (name.lexeme.startsWith('_')) continue;
          if (isGetter) {
            if (name.lexeme != 'id') others.add('getter ${name.lexeme}');
            continue;
          }
          if (name.lexeme == 'toString') continue;
          operations[name.lexeme] = returnType?.toSource() ?? 'dynamic';
        default:
          others.add(member.toSource().split('\n').first);
      }
    }

    expect(
      others,
      isEmpty,
      reason: 'Secret exposes only `info`, `id`, `toString` and its operations',
    );
    expect(
      operations.keys.toSet(),
      inventory.keys.toSet(),
      reason:
          'every public member of Secret is an operation and belongs in the inventory above, with its verdict — whatever it returns',
    );
    for (final MapEntry(key: name, value: type) in operations.entries) {
      expect(
        type,
        startsWith('Future<Result<'),
        reason:
            'Secret.$name returns $type — every operation returns Future<Result<…, SecretFailure>>, the one type a caller handles',
      );
    }

    expect(
      inventory.entries.where((e) => e.value == 'material').map((e) => e.key),
      unorderedEquals(['bip85Hex', 'bip85Mnemonic', 'swapKey', 'revealWords']),
      reason: 'the four that hand back key material; README must match',
    );
  });
}
