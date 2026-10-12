import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/exchange_preferences.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:meta/meta.dart';

class UpdateExchangePreferencesUsecase {
  final ExchangeFacade _exchangeFacade;

  const UpdateExchangePreferencesUsecase({required this._exchangeFacade});

  @useResult
  Future<Result<void, ExchangeSettingsFailure>> execute(
    ExchangePreferences preferences,
  ) async {
    final result = await _exchangeFacade.savePreferences(
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
