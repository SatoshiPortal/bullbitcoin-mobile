import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/exchange_preferences.dart';
import '../exchange_settings_failure.dart';

class GetExchangePreferencesUsecase {
  final Exchange _exchange;

  const GetExchangePreferencesUsecase({required this._exchange});

  @useResult
  Future<Result<ExchangePreferences, ExchangeSettingsFailure>>
  execute() async => (await _exchange.getUserSummary())
      .map(
        (summary) => ExchangePreferences(
          language: summary.language,
          currency: summary.currency,
          emailNotificationsEnabled: summary.emailNotificationsEnabled,
        ),
      )
      .mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() ||
          ExchangeSessionRejectedFailure() =>
            const ExchangeSettingsNotAuthenticatedFailure(),
          _ => const ExchangeSettingsAccountUnavailableFailure(),
        },
      );
}
