import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/exchange_preferences.dart';
import '../exchange_settings_failure.dart';

typedef SaveAccountPreferences = Future<Result<void, ExchangeFailure>> Function(
  ExchangePreferencesPatch,
);

class UpdateExchangePreferencesUsecase {
  final SaveAccountPreferences _save;

  const UpdateExchangePreferencesUsecase({required this._save});

  /// Sends only what the user changed from [loaded]: a field left alone is
  /// not overwritten, even if the account changed it meanwhile.
  @useResult
  Future<Result<void, ExchangeSettingsFailure>> execute({
    required ExchangePreferences loaded,
    required ExchangePreferences edited,
  }) async {
    final result = await _save(
      ExchangePreferencesPatch(
        language: edited.language == loaded.language ? null : edited.language,
        currency: edited.currency == loaded.currency ? null : edited.currency,
        emailNotificationsEnabled:
            edited.emailNotificationsEnabled == loaded.emailNotificationsEnabled
            ? null
            : edited.emailNotificationsEnabled,
      ),
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
