sealed class SettingsApplicationError implements Exception {
  final String message;
  final Object? cause;
  const SettingsApplicationError(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

class FailedToSetBitcoinUnit extends SettingsApplicationError {
  const FailedToSetBitcoinUnit(super.message, {super.cause});
}

class FailedToSetFiatCurrency extends SettingsApplicationError {
  const FailedToSetFiatCurrency(super.message, {super.cause});
}

class FailedToSetLanguage extends SettingsApplicationError {
  const FailedToSetLanguage(super.message, {super.cause});
}

class FailedToSetThemeMode extends SettingsApplicationError {
  const FailedToSetThemeMode(super.message, {super.cause});
}

class FailedToSetAmountVisibility extends SettingsApplicationError {
  const FailedToSetAmountVisibility(super.message, {super.cause});
}

class FailedToSetEnvironmentMode extends SettingsApplicationError {
  const FailedToSetEnvironmentMode(super.message, {super.cause});
}

class FailedToSetSuperuserMode extends SettingsApplicationError {
  const FailedToSetSuperuserMode(super.message, {super.cause});
}

class FailedToSetFeatureLevel extends SettingsApplicationError {
  const FailedToSetFeatureLevel(super.message, {super.cause});
}

class FailedToGetAppSettings extends SettingsApplicationError {
  const FailedToGetAppSettings(super.message, {super.cause});
}
