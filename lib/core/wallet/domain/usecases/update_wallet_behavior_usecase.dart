import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_preferences_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:meta/meta.dart';

final class UpdateWalletBehaviorUsecase {
  final WalletPreferencesRepository _repository;

  const UpdateWalletBehaviorUsecase(this._repository);

  @useResult
  Future<Result<WalletPreferences, WalletPreferencesFailure>> execute({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) {
    return _repository.updateBehavior(
      walletRef: walletId,
      hideOnHome: hideOnHome,
      autoSweepEnabled: autoSweepEnabled,
    );
  }
}
