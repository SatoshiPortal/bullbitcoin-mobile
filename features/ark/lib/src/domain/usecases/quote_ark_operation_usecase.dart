import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_preferences_repository.dart';
import '../repositories/ark_repository.dart';

final class QuoteArkOperationUsecase {
  final ArkRepository _repository;
  final ArkPreferencesRepository _preferences;
  const QuoteArkOperationUsecase(this._repository, this._preferences);

  Future<Result<ArkQuote, ArkFailure>> execute(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) async {
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    if (request is ArkPaymentQuoteRequest || request is ArkBoardQuoteRequest) {
      switch (await _preferences.isEnabled(account)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: false):
          return const Err(ArkDisabledFailure());
        case Ok():
          break;
      }
    }
    // Native validates selection, current balance, recovery and fee authority.
    // Keeping this at the native boundary avoids granting spend from a cache.
    final result = await _repository.quote(account, request);
    if (result case Ok(:final value)) {
      if (value.account != account) return const Err(ArkUnexpectedFailure());
    }
    return result;
  }
}
