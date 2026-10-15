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
  late bdk.DescriptorSecretKey testRoot;

  setUpAll(() async {
    FakeSecureStoragePlatform().install();
    secret = ok(
      await Secrets(
        scratchDirectory: () async => '/tmp',
      ).import(words: words.split(' ')),
    );
    final mnemonic = bdk.Mnemonic.fromString(mnemonic: words);
    try {
      root = bdk.DescriptorSecretKey(
        networkKind: bdk.NetworkKind.main,
        mnemonic: mnemonic,
        password: null,
      );
      testRoot = bdk.DescriptorSecretKey(
        networkKind: bdk.NetworkKind.test,
        mnemonic: mnemonic,
        password: null,
      );
    } finally {
      mnemonic.dispose();
    }
  });

  tearDownAll(() {
    root.dispose();
    testRoot.dispose();
  });

  /// bdk's account xpub, as a bare base58 key.
  String oracle(ScriptType scriptType, int coinType, {int accountIndex = 0}) {
    final path = bdk.DerivationPath(
      path: "m/${scriptType.purpose}'/$coinType'/$accountIndex'",
    );
    bdk.DescriptorSecretKey? derived;
    bdk.DescriptorPublicKey? public;
    try {
      derived = root.derive(path: path);
      public = derived.asPublic();
      // `[fingerprint/path]xpub…` — keep the extended key only.
      return RegExp(
        r'[xt]pub[1-9A-HJ-NP-Za-km-z]+',
      ).firstMatch(public.toString())!.group(0)!;
    } finally {
      public?.dispose();
      derived?.dispose();
      path.dispose();
    }
  }

  String accountZeroDescriptor(
    ScriptType scriptType,
    BitcoinNetwork network,
    bdk.KeychainKind keychain,
  ) {
    final networkKind = network.isMainnet
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;
    // Native templates choose the coin type from networkKind but retain the
    // root key's version bytes. Match the production master xprv encoding.
    final networkRoot = network.isMainnet ? root : testRoot;
    final descriptor = switch (scriptType) {
      ScriptType.bip44 => bdk.Descriptor.newBip44(
        secretKey: networkRoot,
        keychainKind: keychain,
        networkKind: networkKind,
      ),
      ScriptType.bip49 => bdk.Descriptor.newBip49(
        secretKey: networkRoot,
        keychainKind: keychain,
        networkKind: networkKind,
      ),
      ScriptType.bip84 => bdk.Descriptor.newBip84(
        secretKey: networkRoot,
        keychainKind: keychain,
        networkKind: networkKind,
      ),
    };
    try {
      return descriptor.toString();
    } finally {
      descriptor.dispose();
    }
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

        test(
          '$network / $scriptType preserves account-zero descriptors',
          () async {
            final descriptors = ok(
              await secret.derive.descriptors.bitcoin(
                network: network,
                scriptType: scriptType,
              ),
            );
            expect(
              descriptors.external,
              accountZeroDescriptor(
                scriptType,
                network,
                bdk.KeychainKind.external_,
              ),
            );
            expect(
              descriptors.internal,
              accountZeroDescriptor(
                scriptType,
                network,
                bdk.KeychainKind.internal,
              ),
            );
          },
        );

        test(
          '$network / $scriptType account-one descriptors match its xpub',
          () async {
            const accountIndex = 1;
            final descriptors = ok(
              await secret.derive.descriptors.bitcoin(
                network: network,
                scriptType: scriptType,
                accountIndex: accountIndex,
              ),
            );
            final xpub = ok(
              await secret.derive.xpub(
                network: network,
                scriptType: scriptType,
                accountIndex: accountIndex,
              ),
            );
            final canonicalType = network.isMainnet
                ? XpubType.xpub
                : XpubType.tpub;
            final canonicalKey = canonicalType.reencode(xpub);
            expect(
              canonicalKey,
              canonicalType.reencode(
                oracle(
                  scriptType,
                  network.coinType,
                  accountIndex: accountIndex,
                ),
              ),
            );
            final origin =
                "[${secret.id.hex}/${scriptType.purpose}'/${network.coinType}'/$accountIndex']";
            for (final (chain, descriptor) in [
              (0, descriptors.external),
              (1, descriptors.internal),
            ]) {
              final key = '$origin$canonicalKey/$chain/*';
              expect(descriptor.split('#').first, switch (scriptType) {
                ScriptType.bip44 => 'pkh($key)',
                ScriptType.bip49 => 'sh(wpkh($key))',
                ScriptType.bip84 => 'wpkh($key)',
              });
            }
          },
        );
      }
    }
  });

  group('Liquid: every network and script type', () {
    for (final network in LiquidNetwork.values) {
      for (final scriptType in ScriptType.values) {
        test('$network / $scriptType', () async {
          final actual = ok(
            await secret.derive.xpub(network: network, scriptType: scriptType),
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
