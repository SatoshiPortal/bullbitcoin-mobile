import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_preferences_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:meta/meta.dart';

final class GetWalletPreferencesUsecase {
  final WalletPreferencesRepository _repository;

  const GetWalletPreferencesUsecase(this._repository);

  @useResult
  Future<Result<List<WalletPreferences>, WalletPreferencesFailure>> execute() {
    return _repository.fetchAll();
  }
}
