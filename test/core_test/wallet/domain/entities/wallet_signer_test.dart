import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one signer can own multiple distinct descriptor keys', () {
    final signer = WalletSigner(
      id: 'signer-0',
      signer: SignerEntity.remote,
      signerDevice: null,
      descriptorKeys: [
        _key(id: 'key-0', xpub: 'xpub-account-0'),
        _key(id: 'key-1', xpub: 'xpub-account-1'),
      ],
    );

    expect(signer.descriptorKeys.map((key) => key.id), ['key-0', 'key-1']);
  });

  test('rejects a descriptor key assigned to another signer', () {
    expect(
      () => WalletSigner(
        id: 'signer-1',
        signer: SignerEntity.none,
        signerDevice: null,
        descriptorKeys: [_key(id: 'key-0', xpub: 'xpub-account-0')],
      ),
      throwsArgumentError,
    );
  });
}

WalletDescriptorKey _key({required String id, required String xpub}) =>
    WalletDescriptorKey(
      id: id,
      signerId: 'signer-0',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: '11223344',
      xpub: xpub,
      derivationPath: "m/48'/0'/0'/2'",
    );
