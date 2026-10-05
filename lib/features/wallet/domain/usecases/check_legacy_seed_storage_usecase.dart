import 'package:bb_mobile/core/seed/domain/repositories/seed_store_type_repository.dart';

class CheckLegacySeedStorageUsecase {
  final SeedStoreTypeRepository _seedStoreTypeRepository;

  const CheckLegacySeedStorageUsecase(this._seedStoreTypeRepository);

  Future<bool> execute() async {
    final storeType = await _seedStoreTypeRepository.fetch();
    return storeType?.isLegacyStorage ?? false;
  }
}
