import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/wallet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const xpub =
      'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';

  for (final network in [Network.bitcoinMainnet, Network.bitcoinTestnet]) {
    for (final script in ScriptType.values) {
      test('preserves xpub metadata for $network $script', () async {
        final metadata = await WalletXpubImport.derive(
          xpub: xpub,
          network: network,
          scriptType: script,
          label: 'Watch only',
        );
        final wrapper = switch (script) {
          ScriptType.bip44 => 'pkh',
          ScriptType.bip49 => 'sh(wpkh',
          ScriptType.bip84 => 'wpkh',
        };
        final suffix = script == ScriptType.bip49 ? '))' : ')';
        expect(
          metadata.id,
          '$wrapper([2bcd33b0/${script.purpose}h/${network.coinType}h/0h]$suffix',
        );
        expect(metadata.masterFingerprint, '');
        expect(metadata.xpubFingerprint, '2bcd33b0');
        expect(metadata.signer, SignerEntity.none);
        expect(metadata.signerDevice, isNull);
        expect(metadata.label, 'Watch only');
        expect(metadata.isDefault, isFalse);
        expect(metadata.isPhysicalBackupTested, isFalse);
        expect(metadata.isEncryptedVaultTested, isFalse);
        expect(metadata.birthday, isNull);
        expect(metadata.externalPublicDescriptor, contains('/0/*'));
        expect(metadata.internalPublicDescriptor, contains('/1/*'));
        // Reimport the stored version-prefixed key: it must retain every field.
        final reopened = await WalletXpubImport.derive(
          xpub: metadata.xpub,
          network: network,
          scriptType: script,
          label: 'Watch only',
        );
        expect(reopened, metadata);
      });
    }
  }

  for (final network in [Network.liquidMainnet, Network.liquidTestnet]) {
    test('keeps unsupported Liquid xpub failure for $network', () {
      expect(
        WalletXpubImport.derive(
          xpub: xpub,
          network: network,
          scriptType: ScriptType.bip84,
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  }
}
