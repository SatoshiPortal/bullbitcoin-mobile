import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletPreferencesRepository {
  Stream<void> get changes;

  @useResult
  Future<Result<List<WalletPreferences>, WalletPreferencesFailure>> fetchAll();

  @useResult
  Future<Result<WalletPreferences, WalletPreferencesFailure>> fetch(
    String walletRef,
  );

  @useResult
  Future<Result<WalletPreferences, WalletPreferencesFailure>>
  applyBehaviorDefaults({
    required String walletRef,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  });

  @useResult
  Future<Result<WalletPreferences, WalletPreferencesFailure>> updateBehavior({
    required String walletRef,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  });

  @useResult
  Future<Result<WalletPreferencesRecoveryApplyResult, WalletPreferencesFailure>>
  applyRecovered(List<WalletPreferencesRecoveryUpdate> updates);
}
