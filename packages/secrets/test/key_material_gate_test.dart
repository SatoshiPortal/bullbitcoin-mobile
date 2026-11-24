import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/key_material_gate.dart';

void main() {
  late Directory fixture;
  late AnalysisContextCollection collection;
  late String repository;

  setUpAll(() {
    var current = Directory.current;
    while (!File('${current.path}/packages/secrets/pubspec.yaml')
        .existsSync()) {
      if (current.parent.path == current.path) {
        throw StateError('No repository');
      }
      current = current.parent;
    }
    repository = current.path;
    fixture = Directory.systemTemp.createTempSync('key_material_gate_');
    final source = File('$repository/.dart_tool/package_config.json');
    final config = jsonDecode(source.readAsStringSync()) as Map;
    for (final package in config['packages'] as List) {
      package['rootUri'] = source.uri
          .resolve(package['rootUri'] as String)
          .toString();
    }
    File('${fixture.path}/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(config));
    File('${fixture.path}/bridge.dart').writeAsStringSync('''
export 'package:bip32_keys/bip32_keys.dart';
export 'package:rust_bindings/bdk.dart' show DescriptorSecretKey;
export 'package:recoverbull/recoverbull.dart';
export 'package:secrets/testing.dart';
''');
    collection = AnalysisContextCollection(
      includedPaths: [fixture.resolveSymbolicLinksSync()],
      sdkPath: dartSdkPath(repository),
    );
  });

  tearDownAll(() async {
    await collection.dispose();
    fixture.deleteSync(recursive: true);
  });

  Future<List<String>> inspect(
    String name,
    String source, {
    String? policyPath,
  }) async {
    final file = File('${fixture.path}/$name.dart')..writeAsStringSync(source);
    final result = await collection
        .contextFor(file.resolveSymbolicLinksSync())
        .currentSession
        .getResolvedUnit(file.resolveSymbolicLinksSync());
    expect(result, isA<ResolvedUnitResult>());
    final resolved = result as ResolvedUnitResult;
    expect(
      resolved.diagnostics.where(
        (d) => d.diagnosticCode.severity.name == 'ERROR',
      ),
      isEmpty,
      reason: 'The regression fixture must resolve successfully',
    );
    return checkUnit(resolved.unit, policyPath ?? 'lib/$name.dart');
  }

  test(
    'the Bitcoin signer may parse its xprv but never mnemonic words',
    () async {
      const path =
          'packages/secrets/lib/src/crypto/signers/bitcoin_signer.dart';
      const xprv = """
import 'package:rust_bindings/bdk.dart' as bdk;
class BitcoinSigner {
  void _wallet(String value) {
    final key = bdk.DescriptorSecretKey.fromString(privateKey: value);
    key.dispose();
  }
}
""";
      expect(await inspect('signer_xprv', xprv, policyPath: path), isEmpty);
      expect(await inspect('outside_signer', xprv), isNotEmpty);
      const words = """
import 'package:rust_bindings/bdk.dart' as bdk;
class BitcoinSigner {
  bdk.Mnemonic _wallet(String value) => bdk.Mnemonic.fromString(mnemonic: value);
}
""";
      expect(
        await inspect('signer_words', words, policyPath: path),
        isNotEmpty,
      );
      expect(
        await inspect(
          'wrong_method',
          xprv.replaceAll('_wallet', '_other'),
          policyPath: path,
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'aliases and getter access resolve to the private seed declaration',
    () async {
      final violations = await inspect('alias', '''
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as words;
List<int> derive(words.Mnemonic input) => input.seed;
''');
      expect(violations.single, endsWith('#Mnemonic.seed'));
    },
  );

  test(
    're-exports, type aliases and constructor tear-offs retain identity',
    () async {
      final violations = await inspect('reexport', '''
import 'bridge.dart' as bridge;
typedef Root = bridge.Bip32Keys;
final factory = Root.fromSeed;
final decrypt = bridge.RecoverBull.restoreBackup;
final descriptor = bridge.DescriptorSecretKey.fromString;
''');
      expect(violations, hasLength(3));
      expect(violations, contains(endsWith('#Bip32Keys.fromSeed')));
      expect(violations, contains(endsWith('#RecoverBull.restoreBackup')));
      expect(violations, contains(endsWith('#DescriptorSecretKey.fromString')));
    },
  );

  test('raw private-key constructors and tear-offs are checked', () async {
    final violations = await inspect('raw_private', '''
import 'dart:typed_data';
import 'bridge.dart' as bridge;
typedef Root = bridge.Bip32Keys;
String derive(Uint8List key, Uint8List chain, bridge.NetworkType network) =>
    Root(key, null, chain, network)
        .derivePath('m/0').toBase58();
final factory = Root.new;
''');
    expect(violations, contains(endsWith('#Bip32Keys.new')));
  });

  test('Base58 private-key loading and tear-offs are checked', () async {
    final violations = await inspect('private_base58', '''
import 'bridge.dart' as bridge;
typedef Root = bridge.Bip32Keys;
String derive(String xprv) =>
    Root.fromBase58(xprv).derivePath("m/0'").toBase58();
final factory = Root.fromBase58;
''');
    expect(violations, contains(endsWith('#Bip32Keys.fromBase58')));
  });

  test(
    'Base58 exemption requires the public adapter file and method',
    () async {
      const path = 'packages/satoshifier/lib/bip32_derivation.dart';
      const source = '''
import 'package:bip32_keys/bip32_keys.dart';
class Bip32Derivation {
  static Bip32Keys getBip32Xpub(String value) => Bip32Keys.fromBase58(value);
}
''';
      expect(
        await inspect('public_adapter', source, policyPath: path),
        isEmpty,
      );
      expect(
        await inspect('wrong_adapter_file', source),
        contains(endsWith('#Bip32Keys.fromBase58')),
      );
      expect(
        await inspect(
          'wrong_adapter_method',
          source.replaceAll('getBip32Xpub', 'other'),
          policyPath: path,
        ),
        contains(endsWith('#Bip32Keys.fromBase58')),
      );
      expect(
        await inspect(
          'wrong_adapter_class',
          source.replaceAll('Bip32Derivation', 'Other'),
          policyPath: path,
        ),
        contains(endsWith('#Bip32Keys.fromBase58')),
      );
    },
  );

  test(
    'satoshifier decoder exemption requires the listed file, class and method',
    () async {
      const path = 'packages/satoshifier/lib/extended_pubkey.dart';
      const source = '''
import 'package:bip32_keys/bip32_keys.dart';
class ExtendedPubkey {
  static Bip32Keys parse(String value) => Bip32Keys.fromBase58(value);
}
''';
      expect(
        await inspect('satoshifier_parse', source, policyPath: path),
        isEmpty,
      );
      expect(
        await inspect(
          'satoshifier_other_method',
          source.replaceAll('parse(', 'other('),
          policyPath: path,
        ),
        contains(endsWith('#Bip32Keys.fromBase58')),
      );
      expect(
        await inspect(
          'satoshifier_other_file',
          source,
          policyPath: 'packages/satoshifier/lib/other.dart',
        ),
        contains(endsWith('#Bip32Keys.fromBase58')),
      );
    },
  );

  test('only the generated bridge of rust_bindings is left unscanned', () {
    final root = Directory.systemTemp.createTempSync('key_material_roots_');
    addTearDown(() => root.deleteSync(recursive: true));
    const header =
        '// This file is automatically generated, so please do not edit it.\n';
    final files = {
      'packages/rust_bindings/lib/src/rust/frb_generated.dart': header,
      'packages/rust_bindings/lib/src/rust/hand_written.dart': '',
      'packages/rust_bindings/lib/src/lwk_consolidate.dart': '',
      'packages/secrets/lib/b.dart': '',
      'packages/sync/lib/c.dart': '',
      'lib/d.dart': '',
    };
    files.forEach((path, content) {
      File('${root.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    });
    final scanned = productionDartFiles(root.path)
        .map((f) => f.substring(root.path.length + 1));
    expect(
      scanned,
      unorderedEquals([
        'packages/rust_bindings/lib/src/rust/hand_written.dart',
        'packages/rust_bindings/lib/src/lwk_consolidate.dart',
        'packages/sync/lib/c.dart',
        'lib/d.dart',
      ]),
    );
  });

  Future<List<String>> inspectReach(String name, String source) async {
    final file = File('${fixture.path}/$name.dart')..writeAsStringSync(source);
    final result = await collection
        .contextFor(file.resolveSymbolicLinksSync())
        .currentSession
        .getResolvedUnit(file.resolveSymbolicLinksSync());
    return checkSecretsReach(
      (result as ResolvedUnitResult).unit,
      'packages/rust_bindings/lib/src/rust/$name.dart',
      root: fixture.path,
    );
  }

  test(
    'a bindings file may not reach package:secrets by any spelling',
    () async {
      final absolute = Uri.file(
        '$repository/packages/secrets/lib/secrets.dart',
      );
      for (final (name, uri) in [
        ('reach_package', 'package:secrets/secrets.dart'),
        ('reach_file', absolute.toString()),
      ]) {
        expect(
          await inspectReach(
            name,
            "import '$uri';\nObject? f(Secret s) => s;\n",
          ),
          isNotEmpty,
          reason: uri,
        );
      }
      expect(
        await inspectReach('reach_none', "import 'dart:io';\nFile? f;\n"),
        isEmpty,
      );
    },
  );

  test('a bindings file may not use secrets through inference, a conditional '
      'alternative or an outside part', () async {
    File('${fixture.path}/secret_source.dart').writeAsStringSync('''
import 'package:secrets/secrets.dart';
Secret? source() => null;
''');
    expect(
      await inspectReach('reach_inferred', '''
import 'secret_source.dart';
Object? f() => source()?.revealMnemonic;
'''),
      isNotEmpty,
    );
    expect(
      await inspectReach(
        'reach_conditional',
        "import 'dart:io' if (dart.library.js_interop) "
            "'package:secrets/secrets.dart';\nFile? f;\n",
      ),
      isNotEmpty,
    );
    final secrets = Uri.file('$repository/packages/secrets/lib/secrets.dart');
    expect(
      await inspectReach(
        'reach_default',
        "export '$secrets' if (dart.library.io) 'dart:core';\n",
      ),
      isNotEmpty,
    );
    File('${fixture.path}/outside_part.dart')
        .writeAsStringSync("part of 'reach_part.dart';\n");
    expect(
      await inspectReach('reach_part', "part 'outside_part.dart';\n"),
      contains(contains('part outside its package')),
    );
  });

  test('a dynamic call to a secret-handing member is checked', () async {
    for (final member in ['revealMnemonic', 'swapKey', 'signPsbt']) {
      expect(
        await inspect(
          'dynamic_$member',
          'Object? probe(dynamic s) => s.$member();',
        ),
        contains(endsWith('unresolved sensitive member $member')),
        reason: member,
      );
    }
  });

  test('a consumer of the word-signing helper is checked', () async {
    expect(
      await inspect('batch_sign_consumer', '''
import 'package:rust_bindings/lwk.dart' as lwk;
Future<List<String>> sign(lwk.Wallet wallet) => lwk.batchSign(
  wallet,
  psets: const [],
  network: lwk.LiquidNetwork.mainnet,
  mnemonic: '',
);
'''),
      contains(endsWith('batchSign')),
    );
  });

  test('the word-signing helper may sign only inside batchSign', () async {
    const path = 'packages/rust_bindings/lib/src/lwk_consolidate.dart';
    const source = '''
import 'package:rust_bindings/lwk.dart';
Future<String> batchSign(Wallet wallet) => wallet.signTx(
  network: LiquidNetwork.mainnet,
  pset: '',
  mnemonic: '',
);
''';
    expect(
      await inspect('batch_sign_helper', source, policyPath: path),
      isEmpty,
    );
    expect(
      await inspect(
        'other_helper',
        source.replaceAll('batchSign', 'other'),
        policyPath: path,
      ),
      contains(endsWith('Wallet.signTx')),
    );
  });

  test(
    'production code may not import the rust_bindings test bridge',
    () async {
      expect(
        await inspect('bridge_test_support', '''
import 'package:rust_bindings/testing.dart' as testing;
Object? api(testing.BullSdkApi a) => a;
'''),
        contains(contains('test-only library')),
      );
    },
  );

  test('test keystore aliases and re-exports retain identity', () async {
    final violations = await inspect('fake_keystore', '''
import 'bridge.dart' as bridge;
typedef Storage = bridge.FakeSecureStoragePlatform;
Object install() => Storage().install();
''');
    expect(violations, isNotEmpty);
    expect(violations, everyElement(contains('package:secrets/src/testing/')));
  });

  test(
    'test support imports and exports are forbidden in production',
    () async {
      expect(
        await inspect('fake_import', '''
import 'package:secrets/testing.dart';
'''),
        isNotEmpty,
      );
      expect(
        await inspect('fake_export', '''
export 'package:secrets/testing.dart';
'''),
        isNotEmpty,
      );
    },
  );

  test(
    'all conditional test-support import and export branches are checked',
    () async {
      for (final directive in ['import', 'export']) {
        for (final (branch, uri) in [
          ('public', 'package:secrets/testing.dart'),
          (
            'internal',
            'package:secrets/src/testing/fake_secure_storage_platform.dart',
          ),
        ]) {
          expect(
            await inspect('conditional_${directive}_$branch', '''
$directive 'dart:core' if (dart.library.html) '$uri';
'''),
            contains(endsWith('$uri#test-only library')),
          );
        }
        expect(
          await inspect('conditional_${directive}_default', '''
$directive 'package:secrets/testing.dart' if (dart.library.io) 'dart:core';
'''),
          contains(endsWith('package:secrets/testing.dart#test-only library')),
        );
      }
    },
  );

  test('test support is blocked across production workspace roots', () async {
    final root = Directory('${fixture.path}/testing_boundary')..createSync();
    const production = [
      'lib/app.dart',
      'packages/consumer/lib/service.dart',
      'features/consumer/lib/feature.dart',
    ];
    for (final path in [...production, 'test/allowed_test.dart']) {
      File('${root.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
import 'package:secrets/testing.dart' as testing;
Object install() => testing.FakeSecureStoragePlatform().install();
''');
    }
    final report = await checkKeyMaterial(root.path);
    expect(report.fileCount, production.length);
    for (final path in production) {
      expect(report.violations, contains(startsWith('$path: ')));
    }
    expect(report.violations, isNot(contains(startsWith('test/'))));
  });

  test('dot shorthand and instance method tear-offs are checked', () async {
    final violations = await inspect('shorthand', '''
import 'package:rust_bindings/bdk.dart' as bdk;
bdk.DescriptorSecretKey secret(String key) => .fromString(privateKey: key);
Object extract(bdk.DescriptorSecretKeyInterface key) => key.secretBytes;
''');
    expect(violations, hasLength(2));
    expect(violations, contains(endsWith('#DescriptorSecretKey.fromString')));
    expect(
      violations,
      contains(endsWith('#DescriptorSecretKeyInterface.secretBytes')),
    );
  });

  test(
    'low-level vault decryption and private BIP85 derivation are checked',
    () async {
      final violations = await inspect('crypto', '''
import 'package:bip85_entropy/bip85_entropy.dart';
import 'package:recoverbull/src/services/encryption.dart';
final child = Bip85Entropy.deriveMnemonic;
final decrypt = EncryptionService.decrypt;
''');
      expect(violations, hasLength(2));
      expect(violations, contains(endsWith('#Bip85Entropy.deriveMnemonic')));
      expect(violations, contains(endsWith('#EncryptionService.decrypt')));
    },
  );

  test(
    'public derivation, validation and child formatting remain available',
    () async {
      expect(
        await inspect('public', '''
import 'dart:typed_data';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bip85_entropy/bip85_entropy.dart';
Bip32Keys publicKey(Uint8List key, Uint8List chain) =>
    Bip32Keys.fromPublicKey(key, chain).derivePath('m/0');
Object format(List<String> words) => Mnemonic.fromWords(words: words).entropy;
Object path(String value) => MnemonicApplication.parsePath(value);
'''),
        isEmpty,
      );
    },
  );

  test(
    'an unrelated class with the same member name is not forbidden',
    () async {
      expect(
        await inspect('lookalike', '''
class Mnemonic { List<int> get seed => []; }
List<int> value(Mnemonic input) => input.seed;
'''),
        isEmpty,
      );
    },
  );

  test(
    'unresolved sensitive access fails closed, including dynamic access',
    () async {
      final violations = await inspect('dynamic', '''
Object seed(dynamic input) => input.seed;
''');
      expect(violations.single, endsWith('unresolved sensitive member seed'));
    },
  );

  const scan = '''
import 'dart:typed_data';
import 'package:rust_bindings/bdk.dart' as bdk;
Object _performDryScan() {
  final words = bdk.Mnemonic.fromEntropy(entropy: Uint8List(16));
  final key = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.main, mnemonic: words, password: null);
  return bdk.Descriptor.newBip84(secretKey: key,
    keychainKind: bdk.KeychainKind.external_, networkKind: bdk.NetworkKind.main);
}
''';
  const scanPath = 'lib/features/wallet/data/bdk_wallet_datasource.dart';

  test('the former pre-import scan has no exemption', () async {
    // The scan now receives public descriptors from `secrets`; deriving them from words in the wallet package is a violation again.
    final violations = await inspect('scan', scan, policyPath: scanPath);
    expect(violations, hasLength(3));
    expect(violations, everyElement(contains('package:bdk_dart/')));
  });

  const swaps = '''
import 'package:rust_bindings/boltz.dart' as boltz;
class SwapMasterKeyModel {
  factory SwapMasterKeyModel.fromBoltz(boltz.SwapMasterKey key) {
    final privateKey = key.xprv;
    final words = key.mnemonic;
    throw StateError('fixture');
  }
  boltz.SwapMasterKey toBoltz() => boltz.SwapMasterKey(
    xprv: '', xpub: '', network: boltz.Network.mainnet, mnemonic: '', fingerprint: '');
}
''';
  const swapPath =
      'packages/swaps/lib/src/data/models/swap_master_key_model.dart';

  test('swap exemption permits only the named model operations', () async {
    expect(await inspect('swap', swaps, policyPath: swapPath), isEmpty);
    expect(await inspect('wrong_swap_file', swaps), hasLength(3));
    expect(
      await inspect(
        'wrong_swap_member',
        swaps.replaceAll('toBoltz', 'other'),
        policyPath: swapPath,
      ),
      hasLength(1),
    );
  });

  test(
    'swap exemption does not authorize deriving a child from wallet words',
    () async {
      final violations = await inspect('swap_create', '''
import 'package:rust_bindings/boltz.dart' as boltz;
class SwapMasterKeyModel {
  Object toBoltz() => boltz.SwapMasterKey.create;
}
''', policyPath: swapPath);
      expect(violations.single, endsWith('#SwapMasterKey.create'));
    },
  );

  test(
    'unresolved production units fail the gate before a green report',
    () async {
      final root = Directory('${fixture.path}/unresolved')..createSync();
      File('${root.path}/lib/app.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('Object create() => MissingType();');
      final report = await checkKeyMaterial(root.path);
      expect(report.fileCount, 1);
      expect(report.violations, contains('lib/app.dart: undefined_function'));
    },
  );

  test(
    'production discovery includes the signer but excludes other custody',
    () {
      final root = Directory('${fixture.path}/discovery')..createSync();
      const included = [
        'lib/app.dart',
        'packages/secrets/lib/src/crypto/signers/bitcoin_signer.dart',
        'packages/other/lib/value.dart',
        'features/other/lib/feature.dart',
      ];
      for (final path in [
        ...included,
        'packages/secrets/lib/private.dart',
        'test/example.dart',
        'lib/example.g.dart',
        'lib/generated/example.dart',
        'lib/vendor/example.dart',
      ]) {
        File('${root.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync('');
      }
      expect(
        productionDartFiles(root.path),
        unorderedEquals([for (final path in included) '${root.path}/$path']),
      );
    },
  );

  test('seed-based Liquid and swap entry points are checked', () async {
    final violations = await inspect('seed_entry_points', '''
import 'package:rust_bindings/boltz.dart' as boltz;
import 'package:rust_bindings/lwk.dart' as lwk;
final descriptor = lwk.Descriptor.newConfidentialFromSeed;
Object sign(lwk.Wallet wallet) => wallet.signTxWithSeed;
Object details(lwk.Wallet wallet) =>
    wallet.signedPsetWithExtraDetailsWithSeed;
final swap = boltz.SwapMasterKey.createFromSeed;
''');
    expect(violations, hasLength(4));
    expect(violations.join(), contains('#Descriptor.newConfidentialFromSeed'));
    expect(violations.join(), contains('#Wallet.signTxWithSeed'));
    expect(
      violations.join(),
      contains('#Wallet.signedPsetWithExtraDetailsWithSeed'),
    );
    expect(violations.join(), contains('#SwapMasterKey.createFromSeed'));
  });

  test(
    'Silent Payments accounts built from words or seed are checked',
    () async {
      final violations = await inspect('bwk_constructors', '''
import 'package:rust_bindings/bwk.dart';
final first = SpAccount.createFromMnemonic;
final second = SpAccount.createFromMnemonicWithScanRuntime;
final third = SpAccount.createFromSeed;
final fourth = SpAccount.createFromSeedWithScanRuntime;
final fifth = deriveSpAddressFromSeed;
''');
      expect(violations, hasLength(5));
    },
  );

  test(
    'the bridge starts only with its own handler: no tracing handler, no mock',
    () async {
      final violations = await inspect('bridge_init', '''
import 'package:rust_bindings/rust_bindings.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
class Trace extends BaseHandler {}
Future<void> traced() => BullSdk.init(handler: Trace());
void mocked(dynamic api) => BullSdk.initMock(api: api);
Future<void> plain() => BullSdk.init();
''');
      expect(violations, hasLength(2));
      expect(violations.join(), contains('BullSdk.init'));
      expect(violations.join(), contains('BullSdk.initMock'));
    },
  );

  test('an inactive relative alternative to test support is checked', () async {
    final violations = await inspect('conditional_relative', '''
import 'dart:core' if (dart.library.html) '../../secrets/lib/testing.dart';
''');
    expect(violations, isNotEmpty);
  });
}
