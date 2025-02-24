import 'package:bb_mobile/core/domain/entities/seed.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/services/wallet_metadata_derivation_service.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:test/test.dart';

class WalletMetadataDerivationFromMnemonicSeedTestCase {
  final Seed seed;
  final Network network;
  final ScriptType scriptType;
  final String label;
  final bool isDefault;
  final String expectedRootFingerprint;
  final String expectedXpubFingerprint;
  final String expectedXpub;
  final String expectedExternalPublicDescriptor;
  final String expectedInternalPublicDescriptor;
  final String expectedName;
  final Exception? expectedException;

  const WalletMetadataDerivationFromMnemonicSeedTestCase({
    required this.seed,
    required this.network,
    required this.scriptType,
    required this.label,
    required this.isDefault,
    required this.expectedRootFingerprint,
    required this.expectedXpubFingerprint,
    required this.expectedXpub,
    required this.expectedExternalPublicDescriptor,
    required this.expectedInternalPublicDescriptor,
    required this.expectedName,
    this.expectedException,
  });
}

class WalletMetadataDerivationFromXpubTestCase {
  final String xpub;
  final Network network;
  final ScriptType scriptType;
  final String label;
  final String expectedXpubFingerprint;
  final String expectedXpub;
  final String expectedExternalPublicDescriptor;
  final String expectedInternalPublicDescriptor;
  final String expectedName;
  final Exception? expectedException;

  const WalletMetadataDerivationFromXpubTestCase({
    required this.xpub,
    required this.network,
    required this.scriptType,
    required this.label,
    required this.expectedXpubFingerprint,
    required this.expectedXpub,
    required this.expectedExternalPublicDescriptor,
    required this.expectedInternalPublicDescriptor,
    required this.expectedName,
    this.expectedException,
  });
}

void main() {
  group('WalletMetadataDerivationServiceImpl - Integration Tests', () {
    late WalletMetadataDerivationServiceImpl service;
    const defaultBitcoinWalletName = 'Secure Bitcoin Wallet';
    const defaultLiquidWalletName = 'Instant Payments Wallet';
    // Test cases
    // TODO: add more test cases for different mnemonics, passphrases, script types, networks, labels, etc.
    //  as well as cases that should throw exceptions
    final List<WalletMetadataDerivationFromMnemonicSeedTestCase>
        fromSeedTestCases = [
      const WalletMetadataDerivationFromMnemonicSeedTestCase(
        seed: Seed.mnemonic(
          mnemonicWords: [
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'about',
          ],
          passphrase: '',
        ),
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        label: '',
        isDefault: true,
        expectedRootFingerprint: '73c5da0a',
        expectedXpubFingerprint: 'fd13aac9',
        expectedXpub:
            'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs',
        expectedExternalPublicDescriptor:
            "wpkh([73c5da0a/84'/0'/0']xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V/0/*)#wc3n3van",
        expectedInternalPublicDescriptor:
            "wpkh([73c5da0a/84'/0'/0']xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V/1/*)#lv5jvedt",
        expectedName: defaultBitcoinWalletName,
      ),
      const WalletMetadataDerivationFromMnemonicSeedTestCase(
        seed: Seed.mnemonic(
          mnemonicWords: [
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'abandon',
            'about',
          ],
          passphrase: '',
        ),
        network: Network.liquidMainnet,
        scriptType: ScriptType.bip84,
        label: '',
        isDefault: true,
        expectedRootFingerprint: '73c5da0a',
        expectedXpubFingerprint: '5a00fb4f',
        expectedXpub:
            'zpub6r5nbp27YaffuknV3Egk4fLJiKWKTqp6CmVGZHLukWsvUfqAiwyuziKxED9juLgQQLB16xdcXYEmycB4Ws1v44W4rrF1mHPmxrG8ZBQ81RP',
        expectedExternalPublicDescriptor:
            'ct(slip77(9c8e4f05c7711a98c838be228bcb84924d4570ca53f35fa1c793e58841d47023),elwpkh([73c5da0a/84h/1776h/0h]xpub6CRFzUgHFDaiDAQFNX7VeV9JNPDRabq6NYSpzVZ8zW8ANUCiDdenkb1gBoEZuXNZb3wPc1SVcDXgD2ww5UBtTb8s8ArAbTkoRQ8qn34KgcY/<0;1>/*))#y8jljyxl',
        expectedInternalPublicDescriptor:
            'ct(slip77(9c8e4f05c7711a98c838be228bcb84924d4570ca53f35fa1c793e58841d47023),elwpkh([73c5da0a/84h/1776h/0h]xpub6CRFzUgHFDaiDAQFNX7VeV9JNPDRabq6NYSpzVZ8zW8ANUCiDdenkb1gBoEZuXNZb3wPc1SVcDXgD2ww5UBtTb8s8ArAbTkoRQ8qn34KgcY/<0;1>/*))#y8jljyxl',
        expectedName: defaultLiquidWalletName,
      ),
    ];
    // TODO: add more test cases for different xpubs, script types, networks, labels, etc.
    //  as well as cases that should throw exceptions
    final List<WalletMetadataDerivationFromXpubTestCase> fromXpubTestCases = [
      const WalletMetadataDerivationFromXpubTestCase(
        xpub:
            'zpub6rEY3sTCCFXMvg2ZCKNpx24PkKR9B2KceCE4uCwbHXvpKZcjR7i6Bk7oB9ZjCoiByM8fPR66cCbLeYBjN6CHmPmtq9pvwzx4b66c5R7Nqpr',
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        label: 'xpub test',
        expectedXpubFingerprint: '8a675c68',
        expectedXpub:
            'zpub6rEY3sTCCFXMvg2ZCKNpx24PkKR9B2KceCE4uCwbHXvpKZcjR7i6Bk7oB9ZjCoiByM8fPR66cCbLeYBjN6CHmPmtq9pvwzx4b66c5R7Nqpr',
        expectedExternalPublicDescriptor:
            "wpkh([8a675c68/84'/0'/0']xpub6Ca1SY7MttSQE5eKXboaXqsPQP8FHnLcoyBdLR9pXXB4DMzGuoNxwcoX8jeZCzQMA4u3tTtygstEsxxbvhNGAvQh6US5nBK63dyKJKmkkpA/0/*)#zuexfxw9",
        expectedInternalPublicDescriptor:
            "wpkh([8a675c68/84'/0'/0']xpub6Ca1SY7MttSQE5eKXboaXqsPQP8FHnLcoyBdLR9pXXB4DMzGuoNxwcoX8jeZCzQMA4u3tTtygstEsxxbvhNGAvQh6US5nBK63dyKJKmkkpA/1/*)#ngu85n7a",
        expectedName: 'xpub test',
      ),
    ];

    setUp(() async {
      await lwk.LibLwk.init();
      service = const WalletMetadataDerivationServiceImpl();
    });

    test('fromSeed', () async {
      for (final test in fromSeedTestCases) {
        try {
          final metadata = await service.fromSeed(
            seed: test.seed,
            network: test.network,
            scriptType: test.scriptType,
            label: test.label,
            isDefault: test.isDefault,
          );

          expect(metadata.masterFingerprint, test.expectedRootFingerprint);
          expect(metadata.xpubFingerprint, test.expectedXpubFingerprint);
          expect(metadata.network, test.network);
          expect(metadata.scriptType, test.scriptType);
          expect(metadata.xpub, test.expectedXpub);
          expect(metadata.externalPublicDescriptor,
              test.expectedExternalPublicDescriptor);
          expect(metadata.internalPublicDescriptor,
              test.expectedInternalPublicDescriptor);
          expect(metadata.source, WalletSource.mnemonic);
          expect(metadata.isDefault, test.isDefault);
          expect(metadata.label, test.label);
          expect(
            metadata.id,
            '${test.expectedXpubFingerprint}:${test.network.name}',
          );
          expect(metadata.name, test.expectedName);
        } catch (e) {
          expect(e, test.expectedException);
        }
      }
    });

    test('fromXpub', () async {
      for (final test in fromXpubTestCases) {
        try {
          final metadata = await service.fromXpub(
            xpub: test.xpub,
            network: test.network,
            scriptType: test.scriptType,
            label: test.label,
          );

          expect(metadata.xpubFingerprint, test.expectedXpubFingerprint);
          expect(metadata.network, test.network);
          expect(metadata.scriptType, test.scriptType);
          expect(metadata.xpub, test.expectedXpub);
          expect(metadata.externalPublicDescriptor,
              test.expectedExternalPublicDescriptor);
          expect(metadata.internalPublicDescriptor,
              test.expectedInternalPublicDescriptor);
          expect(metadata.source, WalletSource.xpub);
          expect(metadata.isDefault, false);
          expect(metadata.label, test.label);
          expect(
            metadata.id,
            '${test.expectedXpubFingerprint}:${test.network.name}',
          );
          expect(metadata.name, test.expectedName);
        } catch (e) {
          expect(e, test.expectedException);
        }
      }
    });
  });
}
