import 'package:bb_mobile/core/wallet/domain/repositories/wallet_preferences_repository.dart';

final class WatchWalletPreferenceChangesUsecase {
  final WalletPreferencesRepository _repository;

  const WatchWalletPreferenceChangesUsecase(this._repository);

  Stream<void> execute() => _repository.changes;
}
