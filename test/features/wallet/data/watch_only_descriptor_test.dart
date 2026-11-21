import 'package:primitives/primitives.dart' show ScriptType;
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

// Published BIP39 test-vector account (abandon … about), m/84'/0'/0'.
const _xpub =
    'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj';

void main() {
  for (final (scriptType, prefix, purpose) in [
    (ScriptType.bip84, 'wpkh(', 84),
    (ScriptType.bip49, 'sh(wpkh(', 49),
    (ScriptType.bip44, 'pkh(', 44),
  ]) {
    test('an imported xpub yields both $scriptType descriptors', () async {
      final metadata = await WalletMetadataService.deriveFromXpub(
        xpub: _xpub,
        network: Network.bitcoinMainnet,
        scriptType: scriptType,
      );
      final origin = "[${metadata.xpubFingerprint}/$purpose'/0'/0']";
      expect(
        metadata.externalPublicDescriptor,
        startsWith('$prefix$origin$_xpub/0/*)'),
      );
      expect(
        metadata.internalPublicDescriptor,
        startsWith('$prefix$origin$_xpub/1/*)'),
      );
    });
  }

  test('a Liquid network is refused', () async {
    await expectLater(
      WalletMetadataService.deriveFromXpub(
        xpub: _xpub,
        network: Network.liquidMainnet,
        scriptType: ScriptType.bip84,
      ),
      throwsUnimplementedError,
    );
  });
}
