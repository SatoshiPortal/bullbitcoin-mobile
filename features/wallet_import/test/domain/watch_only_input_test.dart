import 'package:signers/signers.dart';
import 'package:wallet_import/wallet_import.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WatchOnlyInput.parse', () {
    const descriptor =
        'wpkh([86241f88/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)#n8txaeah';
    const xpub =
        'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
    const liquidDescriptor =
        'wpkh([86241f88/84h/1776h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)';

    test('attaches signerDevice to descriptor imports', () async {
      final result = await WatchOnlyInput.parse(
        descriptor,
        signerDevice: SignerDevice.coldcardQ,
      );

      final entity = (result as Ok).value;
      expect(entity, isA<WatchOnlyDescriptorInput>());
      expect(
        (entity as WatchOnlyDescriptorInput).signerDevice,
        SignerDevice.coldcardQ,
      );
    });

    test('retains hardware provenance when an xpub is scanned', () async {
      final result = await WatchOnlyInput.parse(
        xpub,
        signerDevice: SignerDevice.coldcardQ,
      );

      final entity = (result as Ok).value as WatchOnlyXpubInput;
      expect(entity.signerDevice, SignerDevice.coldcardQ);
      expect(entity.captureEnvironment(NetworkEnv.regtest), isA<Err>());
    });

    test('rejects a signet selection', () async {
      final result = await WatchOnlyInput.parse(
        xpub,
        environment: NetworkEnv.signet,
      );
      expect((result as Err).failure, isA<InvalidWatchOnlyInputFailure>());
    });

    test('rejects Liquid descriptors', () async {
      final result = await WatchOnlyInput.parse(liquidDescriptor);
      expect((result as Err).failure, isA<InvalidWatchOnlyInputFailure>());
    });
  });
}
