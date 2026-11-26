import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

// Version 2, one 100200 sat witness UTXO, one 100000 sat output: 200 sat fee.
const _psbt =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

// Published BIP39 test-vector account (abandon … about), m/84'/0'/0'.
const _xpub =
    'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj';

void main() {
  group('bitcoinPsbtFee', () {
    test('is the inputs less the outputs', () {
      expect(bitcoinPsbtFee(_psbt), isA<Ok<int, SyncFailure>>());
      expect((bitcoinPsbtFee(_psbt) as Ok<int, SyncFailure>).value, 200);
    });

    test('refuses what is not a PSBT', () {
      expect(
        (bitcoinPsbtFee('not a psbt') as Err<int, SyncFailure>).failure,
        isA<SyncInvalidTransactionFailure>(),
      );
    });
  });

  group('bitcoinPublicDescriptor', () {
    String descriptor(Keychain keychain, ScriptType scriptType) =>
        (bitcoinPublicDescriptor(
          xpub: _xpub,
          fingerprint: '73c5da0a',
          scriptType: scriptType,
          keychain: keychain,
          network: BitcoinNetwork.mainnet,
        ) as Ok<String, SyncFailure>).value;

    test('carries the key origin of each script type and keychain', () {
      expect(
        descriptor(Keychain.external, ScriptType.bip84),
        startsWith("wpkh([73c5da0a/84'/0'/0']$_xpub/0/*)#"),
      );
      expect(
        descriptor(Keychain.internal, ScriptType.bip84),
        startsWith("wpkh([73c5da0a/84'/0'/0']$_xpub/1/*)#"),
      );
      expect(
        descriptor(Keychain.external, ScriptType.bip49),
        startsWith("sh(wpkh([73c5da0a/49'/0'/0']$_xpub/0/*))#"),
      );
      expect(
        descriptor(Keychain.external, ScriptType.bip44),
        startsWith("pkh([73c5da0a/44'/0'/0']$_xpub/0/*)#"),
      );
    });

    test('refuses a key that does not parse', () {
      expect(
        (bitcoinPublicDescriptor(
          xpub: 'xpub-not',
          fingerprint: '73c5da0a',
          scriptType: ScriptType.bip84,
          keychain: Keychain.external,
          network: BitcoinNetwork.mainnet,
        ) as Err<String, SyncFailure>).failure,
        isA<SyncInvalidCatalogFailure>(),
      );
    });
  });

  test('the LWK status conflict is an LWK error with its message', () {
    expect(
      isLiquidStatusConflict(
        const lwk.LwkError(msg: 'UpdateOnDifferentStatus { .. }'),
      ),
      isTrue,
    );
    expect(isLiquidStatusConflict(const lwk.LwkError(msg: 'other')), isFalse);
    expect(
      isLiquidStatusConflict(Exception('UpdateOnDifferentStatus')),
      isFalse,
    );
  });

  test('an unreachable server fails the prescan as a connection', () async {
    final result = await prescanBitcoinWallet(
      externalDescriptor: "wpkh([73c5da0a/84'/0'/0']$_xpub/0/*)",
      internalDescriptor: "wpkh([73c5da0a/84'/0'/0']$_xpub/1/*)",
      network: BitcoinNetwork.mainnet,
      connection: const WalletConnection(
        url: 'tcp://127.0.0.1:1',
        timeout: Duration(seconds: 1),
        retry: 0,
        stopGap: 20,
        validateDomain: false,
      ),
    );
    expect(
      (result as Err<({BigInt confirmedSat, int transactions}), SyncFailure>)
          .failure,
      isA<SyncConnectionFailure>(),
    );
  });
}
