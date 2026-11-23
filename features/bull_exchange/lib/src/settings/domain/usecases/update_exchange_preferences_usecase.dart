import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/exchange_preferences.dart';
import '../exchange_settings_failure.dart';

typedef SaveAccountPreferences =
    Future<Result<void, ExchangeFailure>> Function({
      String? language,
      String? currency,
      bool? emailNotificationsEnabled,
    });

class UpdateExchangePreferencesUsecase {
  final SaveAccountPreferences _save;

  const UpdateExchangePreferencesUsecase({required this._save});

  @useResult
  Future<Result<void, ExchangeSettingsFailure>> execute(
    ExchangePreferences preferences,
  ) async {
    final result = await _save(
      language: preferences.language,
      currency: preferences.currency,
      emailNotificationsEnabled: preferences.emailNotificationsEnabled,
    );
    return result.mapErr(
      (failure) => switch (failure) {
        ExchangeNetworkFailure() => ExchangeSettingsNetworkFailure(
          failure.logMessage,
        ),
        ExchangeNotAuthenticatedFailure() =>
          ExchangeSettingsNotAuthenticatedFailure(failure.logMessage),
        _ => ExchangeSettingsPreferencesSaveFailure(failure.logMessage),
      },
    );
  }
}
