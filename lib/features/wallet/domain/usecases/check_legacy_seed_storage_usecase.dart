import 'package:bb_mobile/core/seed/domain/repositories/seed_store_type_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Whether the seeds still sit in the legacy storage format.
///
/// [SeedStoreTypeRepository] is a shared core repository that still throws, so
/// this use case — the first layer the wallet feature owns — is its boundary.
class CheckLegacySeedStorageUsecase {
  final SeedStoreTypeRepository _seedStoreTypeRepository;

  const CheckLegacySeedStorageUsecase(this._seedStoreTypeRepository);

  @useResult
  Future<Result<bool, WalletFailure>> execute() async {
    try {
      final storeType = await _seedStoreTypeRepository.fetch();
      return Ok(storeType?.isLegacyStorage ?? false);
    } catch (e, st) {
      log.warning('Seed store type read failed: ${e.runtimeType}', trace: st);
      return Err(WalletStorageFailure('seed store read: ${e.runtimeType}'));
    }
  }
}
