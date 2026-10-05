import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_store_type_repository.dart';
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

      expect(await usecase.execute(), isTrue);
    });

    test('is false when the committed flag is fss10', () async {
      final usecase = CheckLegacySeedStorageUsecase(
        _FakeSeedStoreTypeRepository(
          storeType: const SeedStoreType(
            storageLibrary: SeedStorageLibrary.fss10,
          ),
        ),
      );

      expect(await usecase.execute(), isFalse);
    });

    test('is false when the flag was never written', () async {
      final usecase = CheckLegacySeedStorageUsecase(
        _FakeSeedStoreTypeRepository(),
      );

      expect(await usecase.execute(), isFalse);
    });

    test('propagates a read failure instead of masking it as a verdict', () {
      final usecase = CheckLegacySeedStorageUsecase(
        _FakeSeedStoreTypeRepository(error: Exception('read failed')),
      );

      expect(usecase.execute(), throwsA(isA<Exception>()));
    });
  });
}
