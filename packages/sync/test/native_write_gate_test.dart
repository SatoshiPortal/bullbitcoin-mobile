import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:test/test.dart';

import '../tool/native_import_allowlist.dart';
import '../tool/native_write_gate.dart';

void main() {
  late Directory fixture;
  late AnalysisContextCollection collection;
  setUpAll(() {
    var root = Directory.current;
    while (!File('${root.path}/packages/sync/pubspec.yaml').existsSync()) {
      if (root.path == root.parent.path) throw StateError('No repository');
      root = root.parent;
    }
    fixture = Directory.systemTemp.createTempSync('native-write-gate-');
    final source = File('${root.path}/.dart_tool/package_config.json');
    final config = jsonDecode(source.readAsStringSync()) as Map;
    for (final package in config['packages'] as List) {
      package['rootUri'] = source.uri
          .resolve(package['rootUri'] as String)
          .toString();
    }
    File('${fixture.path}/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(config));
    File('${fixture.path}/bridge.dart')
        .writeAsStringSync("export 'package:rust_bindings/bdk.dart';");
    collection = AnalysisContextCollection(
      includedPaths: [fixture.path],
      sdkPath: dartSdkPath(root.path),
    );
  });
  tearDownAll(() async {
    await collection.dispose();
    fixture.deleteSync(recursive: true);
  });

  Future<List<String>> inspect(
    String name,
    String source, {
    String path = 'lib/consumer.dart',
  }) async {
    final file = File('${fixture.path}/$name.dart')..writeAsStringSync(source);
    final result = await collection
        .contextFor(file.path)
        .currentSession
        .getResolvedUnit(file.path);
    expect(result, isA<ResolvedUnitResult>());
    final resolved = result as ResolvedUnitResult;
    expect(
      resolved.diagnostics.where(
        (d) => d.diagnosticCode.severity.name == 'ERROR',
      ),
      isEmpty,
      reason: 'Fixture must resolve; unresolved calls are not evidence',
    );
    return checkUnit(resolved.unit, path);
  }

  test(
    'red-green: aliased and reexported persister construction is rejected',
    () async {
      final violations = await inspect('persister', '''
import 'bridge.dart' as sdk;
typedef Store = sdk.Persister;
final create = Store.newSqlite;
''');
      expect(violations, isNotEmpty);
      expect(violations, contains(contains('Persister.newSqlite')));
    },
  );

  test(
    'wallet mutation tear-offs and Liquid entry points are rejected',
    () async {
      final violations = await inspect('mutations', '''
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;
Object persist(bdk.Wallet wallet) => wallet.persist;
Object update(bdk.WalletInterface wallet) => wallet.applyUpdate;
final load = bdk.Wallet.load;
final init = lwk.Wallet.init;
Object sync(lwk.Wallet wallet) => wallet.sync_;
''');
      for (final symbol in [
        'Wallet.persist',
        'WalletInterface.applyUpdate',
        'Wallet.load',
        'Wallet.init',
        'Wallet.sync_',
      ]) {
        expect(violations, contains(contains(symbol)));
      }
    },
  );

  test('the writer is privileged, other package code is not', () async {
    const source =
        "import 'package:rust_bindings/lwk.dart' as lwk; final init = lwk.Wallet.init;";
    for (final folder in ['data/write', 'data/write/sync']) {
      expect(
        await inspect(
          'privileged',
          source,
          path: 'packages/sync/lib/src/$folder/test.dart',
        ),
        isEmpty,
      );
    }
    expect(
      await inspect('root', source, path: 'packages/sync/lib/sync.dart'),
      isNotEmpty,
    );
    expect(await inspect('snapshot', source, path: snapshotModule), isEmpty);
    expect(
      await inspect(
        'other_read',
        source,
        path: 'packages/sync/lib/src/data/read/other.dart',
      ),
      isEmpty,
    );
  });

  test('outside the writer, hydration never extends to mutation', () async {
    const package = 'packages/sync/lib/src';
    final mutation = await inspect('read_mutation', '''
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;
Object persist(bdk.Wallet wallet) => wallet.persist;
Object sync(lwk.Wallet wallet) => wallet.sync_;
''', path: '$package/data/read/other.dart');
    expect(mutation, contains(contains('Wallet.persist')));
    expect(mutation, contains(contains('Wallet.sync_')));
    const hydration =
        "import 'package:rust_bindings/lwk.dart' as lwk; final init = lwk.Wallet.init;";
    for (final path in [
      '$package/domain/other.dart',
      '$package/data/other.dart',
      '$package/data/writer.dart',
      '$package/other.dart',
    ]) {
      expect(
        await inspect('hydration', hydration, path: path),
        contains(contains('Wallet.init')),
        reason: path,
      );
    }
  });

  test('native file deletion and its sync variant are rejected', () async {
    final violations = await inspect('delete', '''
import 'dart:io';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';
void remove(String root, WalletKey key) {
  final path = nativeWalletStoragePath(root, key);
  final alias = File(path);
  alias.deleteSync();
  Directory(path).delete(recursive: true);
}
''');
    expect(violations, contains(contains('native store deletion')));
  });

  test(
    'memory decoy cannot authorize persistence of a supplied wallet',
    () async {
      final violations = await inspect('decoy', """
import 'package:rust_bindings/bdk.dart' as bdk;
void _performDryScan(bdk.Wallet wallet, bdk.Persister disk) {
  final decoy = bdk.Persister.newInMemory();
  wallet.persist(persister: disk);
  decoy.dispose();
}
""", path: 'packages/sync/lib/src/data/chain/bitcoin_prescan.dart');
      expect(violations, contains(contains('Wallet.persist')));
    },
  );

  test(
    'memory decoy cannot authorize a shorthand persistent wallet load',
    () async {
      final violations = await inspect('shorthand_decoy', """
import 'package:rust_bindings/bdk.dart' as bdk;
void _performDryScan(bdk.Descriptor descriptor, bdk.Persister diskStore) {
  final decoy = bdk.Persister.newInMemory();
  bdk.Wallet wallet = .load(descriptor: descriptor, changeDescriptor: descriptor,
      persister: diskStore, lookahead: 25);
  decoy.dispose();
}
""", path: 'packages/sync/lib/src/data/chain/bitcoin_prescan.dart');
      expect(violations, contains(contains('Wallet.load')));
    },
  );

  test('ordinary similarly named application methods are allowed', () async {
    expect(
      await inspect('ordinary', '''
class Document { void persist() {} void applyUpdate() {} }
void update(Document doc) { doc.persist(); doc.applyUpdate(); }
'''),
      isEmpty,
    );
  });

  test(
    'dry scan allows final in-memory persister only in its exact function',
    () async {
      const path = 'packages/sync/lib/src/data/chain/bitcoin_prescan.dart';
      const memory = '''
import 'package:rust_bindings/bdk.dart' as bdk;
void _performDryScan(bdk.Descriptor descriptor) {
  final store = bdk.Persister.newInMemory();
  final wallet = bdk.Wallet(descriptor: descriptor, changeDescriptor: descriptor,
    network: bdk.Network.testnet, persister: store, lookahead: 25);
  wallet.persist(persister: store);
}
''';
      expect(await inspect('memory', memory, path: path), isEmpty);
      expect(
        await inspect(
          'inline_memory',
          memory
              .replaceAll('final store = bdk.Persister.newInMemory();', '')
              .replaceAll(
                'persister: store',
                'persister: bdk.Persister.newInMemory()',
              ),
          path: path,
        ),
        isEmpty,
      );
      expect(
        await inspect(
          'persistent',
          memory.replaceAll('newInMemory()', "newSqlite(path: 'wallet')"),
          path: path,
        ),
        isNotEmpty,
      );
      expect(
        await inspect(
          'wrong_function',
          memory.replaceAll('_performDryScan', 'other'),
          path: path,
        ),
        isNotEmpty,
      );
      expect(await inspect('wrong_file', memory), isNotEmpty);
    },
  );
  test('read modules allow hydration but never mutation or deletion', () async {
    final violations = await inspect('read_mutations', '''
import 'dart:io';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;
void mutate(bdk.Wallet wallet, bdk.Persister store) {
  wallet.persist(persister: store);
  wallet.revealNextAddress(keychain: bdk.KeychainKind.external_);
  File('store').deleteSync();
}
Object sync(lwk.Wallet wallet) => wallet.sync_;
''', path: snapshotModule);
    for (final symbol in [
      'Wallet.persist',
      'Wallet.revealNextAddress',
      'Wallet.sync_',
      'native store deletion',
    ]) {
      expect(violations, contains(contains(symbol)));
    }
  });

  test(
    'Liquid signer requires createTemp provenance and forbids sync',
    () async {
      const signerPath =
          'packages/secrets/lib/src/crypto/signers/liquid_signer.dart';
      String source(String initializer, {bool sync = false}) =>
          '''
import 'dart:io';
import 'package:rust_bindings/lwk.dart' as lwk;
class LiquidSigner {
  Future<void> signPset(Directory parent, lwk.Descriptor descriptor) async {
    final scratch = $initializer;
    final wallet = await lwk.Wallet.init(network: lwk.LiquidNetwork.testnet, dbpath: scratch.path, descriptor: descriptor);
    ${sync ? 'await wallet.sync_(electrumUrl: "tcp://localhost:1", validateDomain: false);' : ''}
    await scratch.delete(recursive: true);
  }
}
''';
      expect(
        await inspect(
          'scratch_valid',
          source("await parent.createTemp('lwk_sign_')"),
          path: signerPath,
        ),
        isEmpty,
      );
      expect(
        await inspect('scratch_invalid', source('parent'), path: signerPath),
        contains(contains('Wallet.init')),
      );
      expect(
        await inspect(
          'scratch_sync',
          source("await parent.createTemp('lwk_sign_')", sync: true),
          path: signerPath,
        ),
        contains(contains('Wallet.sync_')),
      );
    },
  );

  test('Bitcoin signer proves its single in-memory assignment', () async {
    const signerPath =
        'packages/secrets/lib/src/crypto/signers/bitcoin_signer.dart';
    String source(String factory) =>
        '''
import 'package:rust_bindings/bdk.dart' as bdk;
class BitcoinSigner {
  bdk.Wallet _wallet(bdk.Descriptor descriptor) {
    bdk.Persister? persister;
    try {
      persister = $factory;
      return bdk.Wallet(descriptor: descriptor, changeDescriptor: descriptor, network: bdk.Network.testnet, persister: persister, lookahead: 25);
    } finally { persister?.dispose(); }
  }
}
''';
    expect(
      await inspect(
        'memory_signer',
        source('bdk.Persister.newInMemory()'),
        path: signerPath,
      ),
      isEmpty,
    );
    expect(
      await inspect(
        'memory_signer_dispose_tearoff',
        source('bdk.Persister.newInMemory()').replaceFirst(
          'persister?.dispose();',
          'final releases = [persister?.dispose]; for (final release in releases.nonNulls) { release(); }',
        ),
        path: signerPath,
      ),
      isEmpty,
    );
    expect(
      await inspect(
        'disk_signer',
        source("bdk.Persister.newSqlite(path: 'disk')"),
        path: signerPath,
      ),
      isNotEmpty,
    );
  });

  Future<List<String>> inspectImports(
    String name,
    String source,
    String path,
  ) async {
    final file = File('${fixture.path}/$name.dart')..writeAsStringSync(source);
    final result = await collection
        .contextFor(file.path)
        .currentSession
        .getResolvedUnit(file.path);
    return checkNativeImports((result as ResolvedUnitResult).unit, path);
  }

  test('red-green: generated-looking paths are still checked', () async {
    // A helper named or placed like generated code imports BDK and
    // persists; the app calls an ordinary function of it.
    final repository = Directory('${fixture.path}/repository');
    void write(String path, String source) => File('${repository.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(source);
    // The app's analysis options exclude generated parts; the gate must
    // still inspect them.
    write('analysis_options.yaml', '''
analyzer:
  exclude:
    - lib/**/*.g.dart
''');
    write('lib/generated/native_bridge.dart', '''
import 'package:rust_bindings/bdk.dart' as bdk;
bool owns(Object wallet) => wallet is bdk.Wallet;
''');
    write('lib/wallet_store.g.dart', '''
import 'package:rust_bindings/bdk.dart' as bdk;
void save(bdk.Wallet wallet, bdk.Persister store) =>
    wallet.persist(persister: store);
''');
    write('lib/app.dart', '''
import 'generated/native_bridge.dart';
import 'wallet_store.g.dart';
bool check(Object wallet) => owns(wallet);
final store = save;
''');
    final report = await checkNativeWrites(repository.path);
    expect(
      report.violations,
      contains(
        'lib/generated/native_bridge.dart: '
        'BDK/LWK outside sync (native import ratchet)',
      ),
    );
    expect(
      report.violations,
      contains(
        'lib/wallet_store.g.dart: '
        'BDK/LWK outside sync (native import ratchet)',
      ),
    );
    expect(
      report.violations,
      contains(
        allOf(
          startsWith('lib/wallet_store.g.dart'),
          contains('Wallet.persist'),
        ),
      ),
    );
  });

  group('native import ratchet', () {
    const direct =
        "import 'package:rust_bindings/bdk.dart' as bdk; bdk.Network? n;";
    const bridged = "import 'bridge.dart' as sdk; sdk.Network? n;";

    test('rejects BDK or LWK outside sync, even through a bridge', () async {
      for (final (name, source) in [
        ('import_direct', direct),
        ('import_bridge', bridged),
        (
          'import_lwk',
          "import 'package:rust_bindings/lwk.dart' as lwk; lwk.Wallet? w;",
        ),
      ]) {
        expect(
          await inspectImports(name, source, 'lib/features/x/data/y.dart'),
          contains(contains('native import ratchet')),
          reason: name,
        );
      }
    });

    test('allows sync by directory and listed files only', () async {
      expect(
        await inspectImports(
          'import_owner',
          direct,
          'packages/sync/lib/src/x.dart',
        ),
        isEmpty,
      );
      expect(
        await inspectImports(
          'import_listed',
          direct,
          nativeImportAllowlist.first,
        ),
        isEmpty,
      );
      expect(
        await inspectImports(
          'import_none',
          "import 'dart:io'; File? f;",
          'lib/features/x/data/y.dart',
        ),
        isEmpty,
      );
    });

    test('rust_bindings declares the bindings, satoshifier only its listed parsers', () async {
      expect(
        await inspectImports(
          'import_provider',
          direct,
          'packages/rust_bindings/lib/src/lwk_consolidate.dart',
        ),
        isEmpty,
      );
      expect(
        await inspectImports(
          'import_satoshifier_unlisted',
          direct,
          'packages/satoshifier/lib/new_parser.dart',
        ),
        contains(contains('native import ratchet')),
      );
    });

    test('a listed file that stopped using BDK must leave the list', () {
      final listed = nativeImportAllowlist.first;
      expect(staleNativeImportEntries(nativeImportAllowlist.skip(1).toSet()), [
        contains(listed),
      ]);
      expect(staleNativeImportEntries(nativeImportAllowlist), isEmpty);
    });
  });

  test('outside sync, only secrets and four satoshifier parsers may use BDK or LWK', () {
    expect(
      nativeImportAllowlist.where(
        (path) => !path.startsWith('packages/secrets/'),
      ),
      unorderedEquals([
        'packages/satoshifier/lib/enums/network.dart',
        'packages/satoshifier/lib/parsers/bitcoin_address_parser.dart',
        'packages/satoshifier/lib/parsers/liquid_address_parser.dart',
        'packages/satoshifier/lib/parsers/psbt_parser.dart',
      ]),
    );
  });
}
