import 'package:bb_mobile/features/settings/domain/value_objects/currency_settings.dart';
import 'package:bb_mobile/features/settings/domain/value_objects/display_settings.dart';
import 'package:bb_mobile/features/settings/domain/value_objects/environment_settings.dart';
import 'package:meta/meta.dart';

@immutable
class AppSettings {
  final DisplaySettings display;
  final CurrencySettings currency;
  final EnvironmentSettings environment;

  const AppSettings({
    required this.display,
    required this.currency,
    required this.environment,
  });

  // Note: Normally, entities have dedicated update methods with validation.
  // However, for settings with simple enum/primitive values and no free-text input,
  // a simple copyWith is sufficient and avoids unnecessary boilerplate.
  AppSettings copyWith({
    DisplaySettings? display,
    CurrencySettings? currency,
    EnvironmentSettings? environment,
  }) {
    return AppSettings(
      display: display ?? this.display,
      currency: currency ?? this.currency,
      environment: environment ?? this.environment,
    );
  }
}
