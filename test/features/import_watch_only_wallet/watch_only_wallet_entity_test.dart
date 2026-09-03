import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';

const _xpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';

void main() {
  test('changes xpub display format without changing its canonical key', () {
    final entity =
        const WatchOnlyWalletEntity.xpub(
              extendedPublicKey: _xpub,
              canonicalXpub: _xpub,
              network: Network.bitcoinMainnet,
              scriptType: ScriptType.bip44,
            )
            as WatchOnlyXpubEntity;

    final updated = entity.withScriptType(ScriptType.bip84);

    expect(updated, isA<WatchOnlyXpubEntity>());
    expect(
      (updated as WatchOnlyXpubEntity).extendedPublicKey,
      startsWith('zpub'),
    );
    expect(updated.canonicalXpub, _xpub);
    expect(updated.scriptType, ScriptType.bip84);
  });

  test('updates the device for every key belonging to a signer', () {
    const fingerprint = '12345678';
    final entity =
        WatchOnlyWalletEntity.descriptor(
              descriptor: 'wsh(or_d(pk(key-a),pk(key-b)))',
              network: Network.bitcoinMainnet,
              scriptType: null,
              signers: [
                WalletSigner(
                  id: 'signer-0',
                  signer: SignerEntity.remote,
                  signerDevice: null,
                  descriptorKeys: [
                    WalletDescriptorKey(
                      id: 'key-0',
                      signerId: 'signer-0',
                      masterFingerprint: fingerprint,
                      xpubFingerprint: 'aaaaaaaa',
                      xpub: 'xpub-a',
                      derivationPath: 'm/84h/0h/0h',
                    ),
                    WalletDescriptorKey(
                      id: 'key-1',
                      signerId: 'signer-0',
                      masterFingerprint: fingerprint,
                      xpubFingerprint: 'bbbbbbbb',
                      xpub: 'xpub-b',
                      derivationPath: 'm/84h/0h/1h',
                    ),
                  ],
                ),
              ],
            )
            as WatchOnlyDescriptorEntity;

    expect(entity.signers, hasLength(1));

    final updated = entity.withSignerDevice(
      signerId: entity.signers.single.id,
      signerDevice: SignerDeviceEntity.ledgerFlex,
    );

    expect(updated.signers.single.signerDevice, SignerDeviceEntity.ledgerFlex);
  });
}
