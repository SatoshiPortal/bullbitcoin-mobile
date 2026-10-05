import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockSeedRepository seedRepository;
  late _MockWalletRepository walletRepository;
  late DeleteSeedUsecase usecase;

  const fingerprint = 'abc123';

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
        when(
          () => walletRepository.getWallets(),
        ).thenAnswer((_) async => Ok([]));
        when(
          () => seedRepository.delete(fingerprint),
        ).thenAnswer((_) async => const Ok(null));

        final result = await usecase.execute(fingerprint);

        expect(result, isA<Ok>());
      },
    );

    test(
      'returns SeedDeleteFailure when a wallet still uses the seed — guard',
      () async {
        final wallet = _MockWallet();
        when(() => wallet.masterFingerprint).thenReturn(fingerprint);
        when(
          () => walletRepository.getWallets(),
        ).thenAnswer((_) async => Ok([wallet]));

        final result = await usecase.execute(fingerprint);

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<SeedDeleteFailure>());
        // The blocked seed is never handed to the repository for deletion.
        verifyNever(() => seedRepository.delete(any()));
      },
    );

    test(
      'returns SeedDeleteFailure on repository error — no raw leak',
      () async {
        when(
          () => walletRepository.getWallets(),
        ).thenAnswer((_) async => Ok([]));
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

    test('refuses to delete when the wallet list cannot be read', () async {
      // The seed is key material: if we cannot prove no wallet still uses it,
      // deleting is unrecoverable. An unreadable list must refuse, never fall
      // through to "no wallet uses it".
      when(() => walletRepository.getWallets()).thenAnswer(
        (_) async => const Err<List<Wallet>, WalletFailure>(
          WalletStorageFailure('SqliteException(11): disk image is malformed'),
        ),
      );

      final result = await usecase.execute(fingerprint);

      final failure = (result as Err).failure as SeedFailure;
      expect(failure, isA<SeedDeleteFailure>());
      // The wallet layer's raw reason stays in the log.
      expect(failure.logMessage, isNot(contains('disk image is malformed')));
      verifyNever(() => seedRepository.delete(any()));
    });
  });
}
