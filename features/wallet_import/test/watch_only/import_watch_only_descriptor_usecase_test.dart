import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_descriptor_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';

WatchOnlyDescriptorEntity _descriptor(satoshifier.Network network) =>
    WatchOnlyDescriptorEntity(
      watchOnlyDescriptor: satoshifier.WatchOnlyDescriptor(
        descriptor: satoshifier.Descriptor(
          operand: satoshifier.ScriptOperand.wpkh,
          fingerprint: '86241f88',
          pubkey: 'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7',
          network: network,
          derivation: satoshifier.Derivation.bip84,
          account: 0,
        ),
      ),
    );

void main() {
  final entity = _descriptor(satoshifier.Network.bitcoinMainnet);
  test('rejects Liquid descriptors before persistence', () async {
    final usecase = ImportWatchOnlyDescriptorUsecase(
      ({required descriptor, required signer, required label}) async =>
          fail('Liquid descriptor must not reach provisioning'),
    );
    final result = await usecase.execute(
      watchOnlyDescriptor: _descriptor(satoshifier.Network.liquidMainnet),
    );
    expect(
      result,
      isA<Err<void, ImportWatchOnlyFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<InvalidFormatFailure>(),
      ),
    );
  });

  for (final outcome in <Result<void, ImportWatchOnlyFailure>>[
    const Ok(null),
    const Err(WalletAlreadyExistsFailure()),
    const Err(ImportFailedFailure()),
  ]) {
    test(
      'forwards the selected descriptor and its ${outcome.runtimeType}',
      () async {
        final usecase = ImportWatchOnlyDescriptorUsecase(({
          required descriptor,
          required signer,
          required label,
        }) async {
          expect(descriptor.pubkey, entity.pubkey);
          expect(descriptor.network, BitcoinNetwork.mainnet);
          expect(signer, SignerEntity.remote);
          expect(label, 'Reviewed wallet');
          return outcome;
        });
        expect(
          await usecase.execute(
            watchOnlyDescriptor: entity.copyWith(label: 'Reviewed wallet'),
          ),
          same(outcome),
        );
      },
    );
  }
}
