import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WatchOnlyWalletEntity.parse', () {
    const descriptor =
        'wpkh([86241f88/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)#ht0s3dna';
    const xpub =
        'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';

    test('attaches signerDevice to descriptor imports', () async {
      final entity = await WatchOnlyWalletEntity.parse(
        descriptor,
        signerDevice: SignerDeviceEntity.coldcardQ,
      );

      expect(entity, isA<WatchOnlyDescriptorEntity>());
      expect(
        (entity as WatchOnlyDescriptorEntity).signerDevice,
        SignerDeviceEntity.coldcardQ,
      );
    });

    test('does not attach signerDevice to xpub imports', () async {
      final entity = await WatchOnlyWalletEntity.parse(
        xpub,
        signerDevice: SignerDeviceEntity.coldcardQ,
      );

      expect(entity, isA<WatchOnlyXpubEntity>());
    });
  });
}
