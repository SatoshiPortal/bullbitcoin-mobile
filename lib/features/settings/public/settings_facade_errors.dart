import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';

/// Public errors that the SettingsFacade can throw.
/// These are the only errors that external features should handle.
sealed class SettingsFacadeError implements Exception {
  final String message;
  final Object? cause;
  const SettingsFacadeError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';

  /// Factory to convert application errors to public facade errors
  factory SettingsFacadeError.fromApplicationError(
    SettingsApplicationError applicationError,
  ) {
    return switch (applicationError) {
      FailedToSetBitcoinUnit() => SetBitcoinUnitFailedError(applicationError),
      FailedToSetFiatCurrency() => SetFiatCurrencyFailedError(applicationError),
      FailedToSetLanguage() => SetLanguageFailedError(applicationError),
      FailedToSetThemeMode() => SetThemeModeFailedError(applicationError),
      FailedToSetAmountVisibility() => SetAmountVisibilityFailedError(applicationError),
      FailedToSetEnvironmentMode() => SetEnvironmentModeFailedError(applicationError),
      FailedToSetSuperuserMode() => SetSuperuserModeFailedError(applicationError),
      FailedToSetFeatureLevel() => SetFeatureLevelFailedError(applicationError),
      FailedToGetAppSettings() => GetSettingsFailedError(applicationError),
      _ => UnknownSettingsError(applicationError),
    };
  }
}

/// Thrown when setting Bitcoin unit fails
class SetBitcoinUnitFailedError extends SettingsFacadeError {
  const SetBitcoinUnitFailedError(Object? cause)
      : super('Failed to update Bitcoin unit setting.', cause: cause);
}

/// Thrown when setting fiat currency fails
class SetFiatCurrencyFailedError extends SettingsFacadeError {
  const SetFiatCurrencyFailedError(Object? cause)
      : super('Failed to update fiat currency setting.', cause: cause);
}

/// Thrown when setting language fails
class SetLanguageFailedError extends SettingsFacadeError {
  const SetLanguageFailedError(Object? cause)
      : super('Failed to update language setting.', cause: cause);
}

/// Thrown when setting theme mode fails
class SetThemeModeFailedError extends SettingsFacadeError {
  const SetThemeModeFailedError(Object? cause)
      : super('Failed to update theme mode setting.', cause: cause);
}

/// Thrown when setting amount visibility fails
class SetAmountVisibilityFailedError extends SettingsFacadeError {
  const SetAmountVisibilityFailedError(Object? cause)
      : super('Failed to update amount visibility setting.', cause: cause);
}

/// Thrown when setting environment mode fails
class SetEnvironmentModeFailedError extends SettingsFacadeError {
  const SetEnvironmentModeFailedError(Object? cause)
      : super('Failed to update environment mode setting.', cause: cause);
}

/// Thrown when setting superuser mode fails
class SetSuperuserModeFailedError extends SettingsFacadeError {
  const SetSuperuserModeFailedError(Object? cause)
      : super('Failed to update superuser mode setting.', cause: cause);
}

/// Thrown when setting feature level fails
class SetFeatureLevelFailedError extends SettingsFacadeError {
  const SetFeatureLevelFailedError(Object? cause)
      : super('Failed to update feature level setting.', cause: cause);
}

/// Thrown when getting settings fails
class GetSettingsFailedError extends SettingsFacadeError {
  const GetSettingsFailedError(Object? cause)
      : super('Failed to retrieve settings.', cause: cause);
}

/// Thrown for any unexpected error
class UnknownSettingsError extends SettingsFacadeError {
  const UnknownSettingsError(Object? cause)
      : super('An unknown error occurred.', cause: cause);
}
