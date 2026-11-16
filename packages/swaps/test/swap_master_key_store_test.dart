import 'dart:async';
import 'dart:convert';

import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/domain/entities/derived_swap_master_key.dart';
import 'package:swaps/src/util.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRowStore extends Mock implements SwapRowStore {}

class _MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  final held = <String, Completer<void>>{};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async {
    await held[key]?.future;
    return values[key];
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late _MemorySecretStore secrets;
  late BoltzDatasource boltz;

  const key = DerivedSwapMasterKey(
    walletFingerprint: 'f00dbabe',
    xprv: 'xprv-swap',
    xpub: 'xpub-swap',
    mnemonic: 'swap words',
    fingerprint: 'cafe0001',
    isTestnet: false,
  );

  setUp(() {
    secrets = _MemorySecretStore();
    boltz = BoltzDatasource(
      url: 'boltz.test',
      boltzStore: SwapStorage(rows: _MockRowStore(), secrets: secrets),
    );
  });

  test('stores a derived key in the layout earlier releases wrote', () async {
    await boltz.storeSwapMasterKey(key: key, isTestnet: false);

    expect(secrets.values.keys, ['swap_master_key_mainnet_f00dbabe']);
    expect(jsonDecode(secrets.values['swap_master_key_mainnet_f00dbabe']!), {
      'xprv': 'xprv-swap',
      'xpub': 'xpub-swap',
      'network': 'mainnet',
      'mnemonic': 'swap words',
      'fingerprint': 'cafe0001',
    });
    final stored = await boltz.getSwapMasterKey(isTestnet: false);
    expect(stored.fingerprint, 'cafe0001');
  });

  test('refuses a key derived for the other network', () async {
    await expectLater(
      boltz.storeSwapMasterKey(key: key, isTestnet: true),
      throwsA(isA<SwapsException>()),
    );

    expect(secrets.values, isEmpty);
    await expectLater(
      boltz.getSwapMasterKey(isTestnet: true),
      throwsA(isA<StateError>()),
    );
  });

  test('a wallet without a key clears the previous wallet binding', () async {
    await boltz.storeSwapMasterKey(key: key, isTestnet: false);

    expect(
      await boltz.swapMasterKeyReady(
        walletFingerprint: 'deadbeef',
        isTestnet: false,
      ),
      isFalse,
    );

    await expectLater(
      boltz.getSwapMasterKey(isTestnet: false),
      throwsA(isA<StateError>()),
    );
  });

  test('a late readiness lookup cannot bind an older wallet', () async {
    await boltz.storeSwapMasterKey(key: key, isTestnet: false);
    final release = Completer<void>();
    secrets.held['swap_master_key_mainnet_f00dbabe'] = release;

    final old = boltz.swapMasterKeyReady(
      walletFingerprint: 'f00dbabe',
      isTestnet: false,
    );
    await boltz.swapMasterKeyReady(
      walletFingerprint: 'deadbeef',
      isTestnet: false,
    );
    release.complete();

    expect(await old, isFalse);
    await expectLater(
      boltz.getSwapMasterKey(isTestnet: false),
      throwsA(isA<StateError>()),
    );
  });
}
