import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/exchange_preferences.dart';
import '../exchange_settings_failure.dart';

class GetExchangePreferencesUsecase {
  final Exchange _exchange;

  const GetExchangePreferencesUsecase({required this._exchange});

  /// The preferences of [session]'s account; without a session nothing is
  /// read.
  @useResult
  Future<Result<ExchangePreferences, ExchangeSettingsFailure>> execute(
    ExchangeSession? session,
  ) async => switch (session) {
    null => const Err(ExchangeSettingsNotAuthenticatedFailure()),
    final session => _read(session),
  };

  Future<Result<ExchangePreferences, ExchangeSettingsFailure>> _read(
    ExchangeSession session,
  ) async => (await _exchange.getSessionUserSummary(session))
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
