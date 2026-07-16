import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletPreferencesRepository {
  Stream<void> get changes;

  @useResult
  Future<Result<List<WalletPreferences>, WalletPreferencesFailure>> fetchAll();

  @useResult
  Future<Result<Null, WalletPreferencesFailure>> applyRecovered(
    List<WalletPreferences> preferences,
  );
}
