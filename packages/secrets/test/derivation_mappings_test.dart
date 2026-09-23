import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// The two tables the migration rewrote — which network is which coin type,
/// and which script type is which version prefix — checked through the
/// public API with real `Network` values, against bdk deriving the same
/// paths independently. `derivation_vectors_test.dart` pins bip84 on coin
/// type 0 with literal arguments, which bypasses exactly these tables;
/// the code itself records that an earlier attempt at this refactor changed
/// `xpub` and `xpubFingerprint` for every Liquid wallet.
///
/// bdk is the oracle: a second BIP32 implementation, in Rust, that never
/// saw `XpubType`. It encodes every key as xpub/tpub, so its output is
/// relabelled to the expected prefix before comparison — the relabelling
/// is a four-byte swap and the prefix itself is asserted separately.
void main() {
  const words =
      'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';

  late Secret secret;
  late bdk.DescriptorSecretKey root;

  setUpAll(() async {
    FakeSecureStoragePlatform().install();
    secret = ok(
      await Secrets(
        scratchDirectory: () async => '/tmp',
      ).import(words: words.split(' ')),
    );
    root = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.main,
      mnemonic: bdk.Mnemonic.fromString(mnemonic: words),
      password: null,
    );
  });

  /// bdk's account xpub at `m/purpose'/coinType'/0'`, as a bare base58 key.
  String oracle(ScriptType scriptType, int coinType) {
    final derived = root.derive(
      path: bdk.DerivationPath(path: "m/${scriptType.purpose}'/$coinType'/0'"),
    );
    final text = derived.asPublic().toString();
    // `[fingerprint/path]xpub…/*` — keep the extended key only.
    return RegExp(r'[xt]pub[1-9A-HJ-NP-Za-km-z]+').firstMatch(text)!.group(0)!;
  }

  group('Bitcoin: every network and script type', () {
    for (final network in BitcoinNetwork.values) {
      for (final scriptType in ScriptType.values) {
        test('$network / $scriptType', () async {
          final actual = ok(
            await secret.derive.xpub(network: network, scriptType: scriptType),
          );
          final expectedType = scriptType.getXpubType(network);
          expect(
            actual,
            expectedType.reencode(oracle(scriptType, network.coinType)),
            reason:
                'coin type ${network.coinType}, prefix ${expectedType.name}',
          );
          expect(actual, startsWith(expectedType.name));
        });
      }
    }
  });

  group('Liquid: every network and script type', () {
    for (final network in LiquidNetwork.values) {
      for (final scriptType in ScriptType.values) {
        test('$network / $scriptType', () async {
          final actual = ok(
            await secret.derive.liquidXpub(
              network: network,
              scriptType: scriptType,
            ),
          );
          // Liquid keys wear Bitcoin's prefixes for the matching chain;
          // the coin type is Liquid's own — 1776 on mainnet, 1 elsewhere.
          final expectedType = scriptType.getXpubType(
            network.isMainnet ? BitcoinNetwork.mainnet : BitcoinNetwork.testnet,
          );
          expect(
            actual,
            expectedType.reencode(oracle(scriptType, network.coinType)),
            reason:
                'coin type ${network.coinType}, prefix ${expectedType.name}',
          );
          expect(actual, startsWith(expectedType.name));
        });
      }
    }
  });
}
