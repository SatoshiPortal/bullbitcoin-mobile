import 'package:bb_mobile/features/settings/domain/primitives/language.dart';
import 'package:bb_mobile/features/settings/domain/primitives/theme_mode.dart';
import 'package:meta/meta.dart';

@immutable
class DisplaySettings {
  final Language language;
  final ThemeMode themeMode;
  final bool hideAmounts;

  const DisplaySettings({
    required this.language,
    required this.themeMode,
    required this.hideAmounts,
  });

  // Note: Normally, value objects have dedicated update methods with validation.
  // However, for settings with simple enum/primitive values and no free-text input,
  // a simple copyWith is sufficient and avoids unnecessary boilerplate.
  DisplaySettings copyWith({
    Language? language,
    ThemeMode? themeMode,
    bool? hideAmounts,
  }) {
    return DisplaySettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      hideAmounts: hideAmounts ?? this.hideAmounts,
    );
  }
}
