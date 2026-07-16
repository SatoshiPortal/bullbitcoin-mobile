import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_preferences_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:meta/meta.dart';

final class ApplyRecoveredWalletPreferencesUsecase {
  final WalletPreferencesRepository _repository;

  const ApplyRecoveredWalletPreferencesUsecase(this._repository);

  @useResult
  Future<Result<Null, WalletPreferencesFailure>> execute(
    List<WalletPreferences> preferences,
  ) {
    return _repository.applyRecovered(preferences);
  }
}
