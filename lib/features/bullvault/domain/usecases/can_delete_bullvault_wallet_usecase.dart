import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

final class CanDeleteBullVaultWalletUsecase {
  final BullVaultRepository _repository;

  const CanDeleteBullVaultWalletUsecase(this._repository);

  @useResult
  Future<Result<bool, BullVaultFailure>> execute(String walletId) async {
    final result = await _repository.getByWalletId(walletId);
    return switch (result) {
      Ok(value: null) => const Ok(true),
      Ok() => const Ok(false),
      Err(:final failure) => Err(failure),
    };
  }
}
