import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockSeedRepository seedRepository;
  late _MockWalletRepository walletRepository;
  late DeleteSeedUsecase usecase;

  const fingerprint = 'deadbeef';

  Wallet wallet({bool protected = false, bool remote = false}) => Wallet(
    origin: 'wallet',
    network: Network.bitcoinTestnet,
    signers: [
      WalletSigner.single(
        masterFingerprint: protected ? 'cafebabe' : fingerprint,
        xpubFingerprint: '12345678',
        xpub: 'xpub',
        signer: remote ? SignerEntity.remote : SignerEntity.local,
        signerDevice: null,
      ).copyWith(localSeedFingerprint: protected ? fingerprint : null),
    ],
    scriptType: ScriptType.bip84,
    publicDescriptor: 'wpkh(xpub/<0;1>/*)',
    balanceSat: BigInt.zero,
  );

  setUp(() {
    seedRepository = _MockSeedRepository();
    walletRepository = _MockWalletRepository();
    usecase = DeleteSeedUsecase(
      seedRepository: seedRepository,
      walletRepository: walletRepository,
    );
  });

  group('DeleteSeedUsecase', () {
    test(
      'returns Ok on successful delete when no wallet uses the seed',
      () async {
        when(() => walletRepository.getWallets()).thenAnswer((_) async => []);
        when(
          () => seedRepository.delete(fingerprint),
        ).thenAnswer((_) async => const Ok(null));

        final result = await usecase.execute(fingerprint);

        expect(result, isA<Ok>());
      },
    );

    for (final protected in [false, true]) {
      test(
        'refuses deletion while a ${protected ? 'protected' : 'standard'} wallet uses the seed',
        () async {
          when(
            () => walletRepository.getWallets(),
          ).thenAnswer((_) async => [wallet(protected: protected)]);

          final result = await usecase.execute(fingerprint);

          expect(result, isA<Err>());
          expect((result as Err).failure, isA<SeedDeleteFailure>());
          // The blocked seed is never handed to the repository for deletion.
          verifyNever(() => seedRepository.delete(any()));
        },
      );
    }

    test('ignores a fingerprint used only by a remote signer', () async {
      when(
        () => walletRepository.getWallets(),
      ).thenAnswer((_) async => [wallet(remote: true)]);
      when(
        () => seedRepository.delete(fingerprint),
      ).thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute(fingerprint);

      expect(result, isA<Ok>());
      verify(() => seedRepository.delete(fingerprint)).called(1);
    });

    test(
      'returns SeedDeleteFailure on repository error — no raw leak',
      () async {
        when(() => walletRepository.getWallets()).thenAnswer((_) async => []);
        when(() => seedRepository.delete(fingerprint)).thenAnswer(
          (_) async => const Err(SeedDeleteFailure('raw storage error')),
        );

        final result = await usecase.execute(fingerprint);

        expect(result, isA<Err>());
        final failure = (result as Err).failure;
        expect(failure, isA<SeedDeleteFailure>());
        // logMessage carries the raw reason for logs — never exposed to the UI.
        expect((failure as SeedDeleteFailure).logMessage, isNotNull);
      },
    );

    test(
      'returns SeedDeleteFailure when wallet lookup throws — no raw leak',
      () async {
        when(() => walletRepository.getWallets()).thenThrow(Exception('boom'));

        final result = await usecase.execute(fingerprint);

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<SeedDeleteFailure>());
        verifyNever(() => seedRepository.delete(any()));
      },
    );
  });
}
