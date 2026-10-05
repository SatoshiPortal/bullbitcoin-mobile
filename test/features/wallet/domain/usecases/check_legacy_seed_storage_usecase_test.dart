import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_store_type_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_legacy_seed_storage_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSeedStoreTypeRepository implements SeedStoreTypeRepository {
  final SeedStoreType? storeType;
  final Exception? error;

  _FakeSeedStoreTypeRepository({this.storeType, this.error});

  @override
  Future<SeedStoreType?> fetch() async {
    if (error != null) throw error!;
    return storeType;
  }
}

/// The verdict of an [Ok]; an [Err] fails the test.
bool _verdict(Result<bool, WalletFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected a verdict, got ${failure.runtimeType}'),
};

void main() {
  group('CheckLegacySeedStorageUsecase', () {
    test('is true when the committed flag is fss9', () async {
      final usecase = CheckLegacySeedStorageUsecase(
        _FakeSeedStoreTypeRepository(
          storeType: const SeedStoreType(
            storageLibrary: SeedStorageLibrary.fss9,
          ),
        ),
      );

      expect(_verdict(await usecase.execute()), isTrue);
    });

    test('is false when the committed flag is fss10', () async {
      final usecase = CheckLegacySeedStorageUsecase(
        _FakeSeedStoreTypeRepository(
          storeType: const SeedStoreType(
            storageLibrary: SeedStorageLibrary.fss10,
          ),
        ),
      );

      expect(_verdict(await usecase.execute()), isFalse);
    });

    test('is false when the flag was never written', () async {
      final usecase = CheckLegacySeedStorageUsecase(
        _FakeSeedStoreTypeRepository(),
      );

      expect(_verdict(await usecase.execute()), isFalse);
    });

    test('reports a read failure instead of masking it as a verdict', () async {
      final usecase = CheckLegacySeedStorageUsecase(
        _FakeSeedStoreTypeRepository(error: Exception('read failed')),
      );

      switch (await usecase.execute()) {
        case Ok():
          fail('a failed read must not read as "not legacy"');
        case Err(:final failure):
          expect(failure, isA<WalletStorageFailure>());
          expect(failure.logMessage, isNot(contains('read failed')));
      }
    });
  });
}
