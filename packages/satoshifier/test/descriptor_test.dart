import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  group('Descriptor', () {
    test('decodes a BIP44 descriptor', () {
      final descriptor = Descriptor.parse(TestValue.descriptorP2pkhBip44);
      expect(descriptor.operand, ScriptOperand.pkh);
      expect(descriptor.pubkey, TestValue.xpub);
      expect(descriptor.fingerprint, TestValue.walletMasterFingerprint);
      expect(descriptor.network, Network.bitcoinMainnet);
      expect(descriptor.derivation, Derivation.bip44);
      expect(descriptor.account, 0);
      expect(descriptor.combined, TestValue.descriptorP2pkhBip44.split('#')[0]);
    });

    test('decodes a BIP49 descriptor', () {
      final descriptor = Descriptor.parse(TestValue.descriptorP2shBip49);
      expect(descriptor.operand, ScriptOperand.shwpkh);
      expect(descriptor.pubkey, TestValue.xpub);
      expect(descriptor.fingerprint, TestValue.walletMasterFingerprint);
      expect(descriptor.network, Network.bitcoinMainnet);
      expect(descriptor.derivation, Derivation.bip49);
      expect(descriptor.account, 0);
      expect(descriptor.combined, TestValue.descriptorP2shBip49.split('#')[0]);
    });

    test('decodes a BIP84 descriptor', () {
      final descriptor = Descriptor.parse(TestValue.descriptorP2wpkhBip84);
      expect(descriptor.operand, ScriptOperand.wpkh);
      expect(descriptor.pubkey, TestValue.xpub);
      expect(descriptor.fingerprint, TestValue.walletMasterFingerprint);
      expect(descriptor.network, Network.bitcoinMainnet);
      expect(descriptor.derivation, Derivation.bip84);
      expect(descriptor.account, 0);
      expect(
        descriptor.combined,
        TestValue.descriptorP2wpkhBip84.split('#')[0], // remove checksum
      );
    });

    test('decodes a testnet descriptor', () async {
      final testnetDescriptor =
          'wpkh([${TestValue.walletMasterFingerprint}/84h/1h/1984h]'
          '${TestValue.testnetTpub}/0/*)';
      final satoshifier = await WatchOnlyDescriptorParser.parse(
        testnetDescriptor,
      );
      expect(satoshifier, isA<WatchOnlyDescriptor>());
      final descriptor = (satoshifier as WatchOnlyDescriptor).descriptor;
      expect(descriptor.operand, ScriptOperand.wpkh);
      expect(descriptor.pubkey, TestValue.testnetTpub);
      expect(descriptor.fingerprint, TestValue.walletMasterFingerprint);
      expect(descriptor.network, Network.bitcoinTestnet);
      expect(descriptor.derivation, Derivation.bip84);
      expect(descriptor.account, 1984);
    });

    test('decodes a change only descriptor', () {
      final descriptor = Descriptor.parse(TestValue.descriptorChangeOnly);
      expect(descriptor.operand, ScriptOperand.shwpkh);
      expect(descriptor.pubkey, TestValue.xpub);
      expect(descriptor.fingerprint, TestValue.walletMasterFingerprint);
      expect(descriptor.network, Network.bitcoinMainnet);
      expect(descriptor.derivation, Derivation.bip49);
      expect(descriptor.account, 0);
    });

    test('decodes a liquid descriptor', () {
      final liquidCoinType = '${CoinType.liquid.value}h';
      final liquidDescriptor =
          'wpkh([${TestValue.walletMasterFingerprint}/84h/$liquidCoinType/0h]${TestValue.xpub}/0/*)';
      final descriptor = Descriptor.parse(liquidDescriptor);
      expect(descriptor.operand, ScriptOperand.wpkh);
      expect(descriptor.pubkey, TestValue.xpub);
      expect(descriptor.fingerprint, TestValue.walletMasterFingerprint);
      expect(descriptor.network, Network.liquidMainnet);
      expect(descriptor.derivation, Derivation.bip84);
      expect(descriptor.account, 0);
    });

    group('creates Descriptor from ExtendedPubkey', () {
      test('creates descriptor from parsed xpub', () {
        final extendedPubkey = ExtendedPubkey.parse(TestValue.xpub);
        final descriptor = Descriptor.fromExtendedPubkey(extendedPubkey);

        expect(descriptor.fingerprint, '');
        expect(descriptor.origin, '');
        expect(descriptor.combined, 'pkh(${TestValue.xpub}/<0;1>/*)');
        expect(descriptor.internal, 'pkh(${TestValue.xpub}/1/*)');
        expect(descriptor.external, 'pkh(${TestValue.xpub}/0/*)');
        expect(descriptor.pubkey, extendedPubkey.xpub);
        expect(descriptor.pubkey, extendedPubkey.pubBase58);
        expect(descriptor.network, extendedPubkey.network);
        expect(descriptor.derivation, extendedPubkey.derivation);
      });

      test('creates descriptor from parsed ypub', () {
        final extendedPubkey = ExtendedPubkey.parse(TestValue.ypub);
        final descriptor = Descriptor.fromExtendedPubkey(extendedPubkey);

        expect(descriptor.fingerprint, '');
        expect(descriptor.origin, '');
        expect(
          descriptor.combined,
          'sh(wpkh(${TestValue.ypubToXpub}/<0;1>/*))',
        );
        expect(descriptor.internal, 'sh(wpkh(${TestValue.ypubToXpub}/1/*))');
        expect(descriptor.external, 'sh(wpkh(${TestValue.ypubToXpub}/0/*))');
        expect(descriptor.pubkey, extendedPubkey.xpub);
        expect(descriptor.network, extendedPubkey.network);
        expect(descriptor.derivation, extendedPubkey.derivation);
      });

      test('creates descriptor from parsed zpub', () {
        final extendedPubkey = ExtendedPubkey.parse(TestValue.zpub);
        final descriptor = Descriptor.fromExtendedPubkey(extendedPubkey);

        expect(descriptor.fingerprint, '');
        expect(descriptor.origin, '');
        expect(descriptor.combined, 'wpkh(${TestValue.zpubToXpub}/<0;1>/*)');
        expect(descriptor.internal, 'wpkh(${TestValue.zpubToXpub}/1/*)');
        expect(descriptor.external, 'wpkh(${TestValue.zpubToXpub}/0/*)');
        expect(descriptor.pubkey, extendedPubkey.xpub);
        expect(descriptor.network, extendedPubkey.network);
        expect(descriptor.derivation, extendedPubkey.derivation);
      });
    });

    group('coinType getter', () {
      test('returns CoinType.bitcoin for bitcoinMainnet', () {
        final descriptor = Descriptor(
          operand: ScriptOperand.pkh,
          fingerprint: TestValue.walletMasterFingerprint,
          pubkey: TestValue.xpub,
          network: Network.bitcoinMainnet,
          derivation: Derivation.bip44,
          account: 0,
        );
        expect(descriptor.coinType, CoinType.bitcoin);
      });

      test('returns CoinType.testnet for all bitcoin testnet variants', () {
        final testnetNetworks = [
          Network.bitcoinTestnet,
          Network.bitcoinSignet,
          Network.bitcoinRegtest,
        ];
        for (final network in testnetNetworks) {
          final descriptor = Descriptor(
            operand: ScriptOperand.pkh,
            fingerprint: TestValue.walletMasterFingerprint,
            pubkey: TestValue.xpub,
            network: network,
            derivation: Derivation.bip44,
            account: 0,
          );
          expect(descriptor.coinType, CoinType.testnet);
        }
      });

      test('returns CoinType.liquid for liquid networks', () {
        final liquidNetworks = [Network.liquidMainnet, Network.liquidTestnet];
        for (final network in liquidNetworks) {
          final descriptor = Descriptor(
            operand: ScriptOperand.pkh,
            fingerprint: TestValue.walletMasterFingerprint,
            pubkey: TestValue.xpub,
            network: network,
            derivation: Derivation.bip44,
            account: 0,
          );
          expect(descriptor.coinType, CoinType.liquid);
        }
      });
    });

    test('fromStrings: 84h Mainnet Account 1', () {
      final d = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: '84h/0h/1h',
        xpub: TestValue.xpub,
      );
      expect(d.operand, ScriptOperand.wpkh);
      expect(d.derivation, Derivation.bip84);
      expect(d.network, Network.bitcoinMainnet);
      expect(d.account, 1);
    });

    test('fromStrings: 84h Testnet Account 0', () {
      final d = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: '84h/1h/0h',
        xpub: TestValue.testnetTpub,
      );
      expect(d.operand, ScriptOperand.wpkh);
      expect(d.derivation, Derivation.bip84);
      expect(d.network, Network.bitcoinTestnet);
      expect(d.account, 0);
    });

    test('fromStrings: 44h Mainnet Account 5', () {
      final d = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: '44h/0h/5h',
        xpub: TestValue.xpub,
      );
      expect(d.operand, ScriptOperand.pkh);
      expect(d.derivation, Derivation.bip44);
      expect(d.network, Network.bitcoinMainnet);
      expect(d.account, 5);
    });

    test('fromStrings: 44h Testnet Account 10', () {
      final d = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: '44h/1h/10h',
        xpub: TestValue.testnetTpub,
      );
      expect(d.operand, ScriptOperand.pkh);
      expect(d.derivation, Derivation.bip44);
      expect(d.network, Network.bitcoinTestnet);
      expect(d.account, 10);
    });

    test('fromStrings: 49h Mainnet Account 1', () {
      final d = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: '49h/0h/1h',
        xpub: TestValue.xpub,
      );
      expect(d.operand, ScriptOperand.shwpkh);
      expect(d.derivation, Derivation.bip49);
      expect(d.network, Network.bitcoinMainnet);
      expect(d.account, 1);
    });

    test('fromStrings: 49h Testnet Account 7', () {
      final d = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: '49h/1h/7h',
        xpub: TestValue.testnetTpub,
      );
      expect(d.operand, ScriptOperand.shwpkh);
      expect(d.derivation, Derivation.bip49);
      expect(d.network, Network.bitcoinTestnet);
      expect(d.account, 7);
    });

    test('fromStrings: supports optional m/ prefix', () {
      final d = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: 'm/49h/1h/7h',
        xpub: TestValue.testnetTpub,
      );
      expect(d.operand, ScriptOperand.shwpkh);
      expect(d.derivation, Derivation.bip49);
      expect(d.network, Network.bitcoinTestnet);
      expect(d.account, 7);
    });

    test('fromStrings: maps liquid coin type to liquid network', () {
      final d = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: '84h/${CoinType.liquid.value}h/0h',
        xpub: TestValue.xpub,
      );
      expect(d.network, Network.liquidMainnet);
      expect(d.derivation, Derivation.bip84);
      expect(d.operand, ScriptOperand.wpkh);
    });

    test('fromStrings: 44h with liquid coin type infers pkh on liquid', () {
      final d = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: '44h/${CoinType.liquid.value}h/9h',
        xpub: TestValue.xpub,
      );
      expect(d.operand, ScriptOperand.pkh);
      expect(d.derivation, Derivation.bip44);
      expect(d.network, Network.liquidMainnet);
      expect(d.account, 9);
    });

    test('parse([origin]xpub): supports apostrophes and no m/', () {
      final d = Descriptor.parse(
        "[${TestValue.walletMasterFingerprint}/84'/0h/0h]${TestValue.xpub}",
      );
      expect(d.operand, ScriptOperand.wpkh);
      expect(d.derivation, Derivation.bip84);
      expect(d.network, Network.bitcoinMainnet);
      expect(d.account, 0);
    });

    test('parse([origin]xpub): 84h on testnet (1h) infers wpkh', () {
      final d = Descriptor.parse(
        '[${TestValue.walletMasterFingerprint}/84h/1h/4h]${TestValue.testnetTpub}',
      );
      expect(d.operand, ScriptOperand.wpkh);
      expect(d.derivation, Derivation.bip84);
      expect(d.network, Network.bitcoinTestnet);
      expect(d.account, 4);
    });

    test('parse([origin]xpub): 84h with liquid coin type infers liquid wpkh', () {
      final d = Descriptor.parse(
        '[${TestValue.walletMasterFingerprint}/84h/${CoinType.liquid.value}h/0h]${TestValue.xpub}',
      );
      expect(d.operand, ScriptOperand.wpkh);
      expect(d.derivation, Derivation.bip84);
      expect(d.network, Network.liquidMainnet);
      expect(d.account, 0);
    });
    test('parse([origin]xpub): 49h infers sh(wpkh) on mainnet', () {
      final d = Descriptor.parse(
        '[${TestValue.walletMasterFingerprint}/49h/0h/0h]${TestValue.xpub}',
      );
      expect(d.operand, ScriptOperand.shwpkh);
      expect(d.derivation, Derivation.bip49);
      expect(d.network, Network.bitcoinMainnet);
      expect(d.account, 0);
    });

    test('parse([origin]xpub): 44h on testnet (1h) infers pkh', () {
      final d = Descriptor.parse(
        '[${TestValue.walletMasterFingerprint}/44h/1h/2h]${TestValue.testnetTpub}',
      );
      expect(d.operand, ScriptOperand.pkh);
      expect(d.derivation, Derivation.bip44);
      expect(d.network, Network.bitcoinTestnet);
      expect(d.account, 2);
    });

    test('parse([origin]xpub): invalid missing closing bracket', () {
      expect(
        () => Descriptor.parse(
          '[${TestValue.walletMasterFingerprint}/84h/0h/0h${TestValue.xpub}',
        ),
        throwsA(
          predicate(
            // Must not carry the input: the same message is reached by a
            // descriptor that embeds a private key.
            (e) =>
                e is String &&
                e.startsWith('Invalid descriptor format') &&
                !e.contains(TestValue.xpub),
          ),
        ),
      );
    });

    test('parse([origin]xpub): invalid insufficient derivation path parts', () {
      expect(
        () => Descriptor.parse(
          '[${TestValue.walletMasterFingerprint}/84h/0h]${TestValue.xpub}',
        ),
        throwsA(
          predicate(
            // Must not carry the input: the same message is reached by a
            // descriptor that embeds a private key.
            (e) =>
                e is String &&
                e.startsWith('Invalid descriptor format') &&
                !e.contains(TestValue.xpub),
          ),
        ),
      );
    });

    test('parse([origin]xpub): invalid non-numeric coin type', () {
      expect(
        () => Descriptor.parse(
          '[${TestValue.walletMasterFingerprint}/84h/xyz/0h]${TestValue.xpub}',
        ),
        throwsA(isA<String>()),
      );
    });
  });

  test('Parse an external descriptor', () {
    final input =
        "wpkh([efbd6844/84'/0'/0']xpub6Bx9HW5yLRBRQLdMFEJ2auFxz2oWyzmFAaD2YvPX61Qnf39b8GB7HpkKGhxx1mqkLioykGdZdHKRjygX8K63Qqv1MCM4Ej1qXnGsf4do3sp/0/*)#zqnrma8y";
    final d = Descriptor.parse(input);

    expect(d.operand, ScriptOperand.wpkh);
    expect(d.derivation, Derivation.bip84);
    expect(d.network, Network.bitcoinMainnet);
    expect(d.account, 0);
  });
}
