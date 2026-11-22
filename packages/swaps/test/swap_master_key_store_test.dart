import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'support/real_swap_backends.dart';

import 'package:primitives/primitives.dart' show NetworkEnv;

import 'dart:async';
import 'dart:convert';

import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/domain/entities/derived_swap_master_key.dart';
import 'package:swaps/src/util.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRowStore extends Mock implements SwapRowStore {}

class _MemoryKeychain extends ReproKeychainBackend {
  final held = <String, Completer<void>>{};
  var readsFail = false;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    await held[key]?.future;
    if (readsFail) throw StateError('keychain unavailable');
    return values[key];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MemoryKeychain secrets;
  late BoltzDatasource boltz;

  const key = DerivedSwapMasterKey(
    walletFingerprint: 'f00dbabe',
    xprv: 'xprv-swap',
    xpub: 'xpub-swap',
    mnemonic: 'swap words',
    fingerprint: 'cafe0001',
    environment: NetworkEnv.mainnet,
  );

  setUp(() {
    secrets = _MemoryKeychain();
    boltz = BoltzDatasource(
      environment: NetworkEnv.mainnet,
      url: 'boltz.test',
      boltzStore: SwapStorage(
        rows: _MockRowStore(),
        secrets: secrets.capability,
      ),
    );
  });

  test('stores a derived key in the layout earlier releases wrote', () async {
    await boltz.storeSwapMasterKey(key: key, environment: NetworkEnv.mainnet);

    expect(secrets.values.keys, ['swap_master_key_mainnet_f00dbabe']);
    expect(jsonDecode(secrets.values['swap_master_key_mainnet_f00dbabe']!), {
      'xprv': 'xprv-swap',
      'xpub': 'xpub-swap',
      'network': 'mainnet',
      'mnemonic': 'swap words',
      'fingerprint': 'cafe0001',
    });
    final stored = await boltz.getSwapMasterKey(
      environment: NetworkEnv.mainnet,
    );
    expect(stored.fingerprint, 'cafe0001');
  });

  test('refuses a key derived for the other network', () async {
    await expectLater(
      boltz.storeSwapMasterKey(key: key, environment: NetworkEnv.testnet),
      throwsA(isA<SwapsException>()),
    );

    expect(secrets.values, isEmpty);
    await expectLater(
      boltz.getSwapMasterKey(environment: NetworkEnv.testnet),
      throwsA(isA<StateError>()),
    );
  });

  test('a stored key is never overwritten by a later derivation', () async {
    await boltz.storeSwapMasterKey(key: key, environment: NetworkEnv.mainnet);

    await boltz.storeSwapMasterKey(
      key: const DerivedSwapMasterKey(
        walletFingerprint: 'f00dbabe',
        xprv: 'xprv-passphrase',
        xpub: 'xpub-passphrase',
        mnemonic: 'other words',
        fingerprint: 'cafe0002',
        environment: NetworkEnv.mainnet,
      ),
      environment: NetworkEnv.mainnet,
    );

    final stored = await boltz.getSwapMasterKey(
      environment: NetworkEnv.mainnet,
    );
    expect(stored.fingerprint, 'cafe0001');
  });

  test('a keychain read failure is not read as a missing key', () async {
    await boltz.storeSwapMasterKey(key: key, environment: NetworkEnv.mainnet);
    secrets.readsFail = true;

    await expectLater(
      boltz.swapMasterKeyReady(
        walletFingerprint: 'f00dbabe',
        environment: NetworkEnv.mainnet,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      boltz.storeSwapMasterKey(key: key, environment: NetworkEnv.mainnet),
      throwsA(isA<StateError>()),
    );
  });

  test('a wallet without a key clears the previous wallet binding', () async {
    await boltz.storeSwapMasterKey(key: key, environment: NetworkEnv.mainnet);

    expect(
      await boltz.swapMasterKeyReady(
        walletFingerprint: 'deadbeef',
        environment: NetworkEnv.mainnet,
      ),
      isFalse,
    );

    await expectLater(
      boltz.getSwapMasterKey(environment: NetworkEnv.mainnet),
      throwsA(isA<StateError>()),
    );
  });

  test('a late readiness lookup cannot bind an older wallet', () async {
    await boltz.storeSwapMasterKey(key: key, environment: NetworkEnv.mainnet);
    final release = Completer<void>();
    secrets.held['swap_master_key_mainnet_f00dbabe'] = release;

    final old = boltz.swapMasterKeyReady(
      walletFingerprint: 'f00dbabe',
      environment: NetworkEnv.mainnet,
    );
    await boltz.swapMasterKeyReady(
      walletFingerprint: 'deadbeef',
      environment: NetworkEnv.mainnet,
    );
    release.complete();

    expect(await old, isFalse);
    await expectLater(
      boltz.getSwapMasterKey(environment: NetworkEnv.mainnet),
      throwsA(isA<StateError>()),
    );
  });
  test(
    'a mismatched stored tag is refused without overwriting or binding it',
    () async {
      final slot = 'swap_master_key_mainnet_f00dbabe';
      final wrong = jsonEncode({
        'xprv': '',
        'xpub': '',
        'mnemonic': '',
        'fingerprint': '00000001',
        'network': 'testnet',
      });
      secrets.values[slot] = wrong;
      await expectLater(
        boltz.swapMasterKeyReady(
          walletFingerprint: 'f00dbabe',
          environment: NetworkEnv.mainnet,
        ),
        throwsA(isA<SwapsException>()),
      );
      expect(secrets.values[slot], wrong);
      await expectLater(
        boltz.getSwapMasterKey(environment: NetworkEnv.mainnet),
        throwsStateError,
      );
    },
  );

  test(
    'a matching foreign key argument cannot write outside the captured engine',
    () async {
      const foreign = DerivedSwapMasterKey(
        walletFingerprint: '00000001',
        xprv: '',
        xpub: '',
        mnemonic: '',
        fingerprint: '00000002',
        environment: NetworkEnv.regtest,
      );
      await expectLater(
        boltz.storeSwapMasterKey(key: foreign, environment: NetworkEnv.regtest),
        throwsA(isA<SwapsException>()),
      );
      expect(secrets.values, isEmpty);
    },
  );
}
