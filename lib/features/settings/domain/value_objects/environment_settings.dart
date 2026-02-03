import 'package:bb_mobile/features/settings/domain/primitives/environment_mode.dart';
import 'package:bb_mobile/features/settings/domain/primitives/feature_level.dart';
import 'package:meta/meta.dart';

@immutable
class EnvironmentSettings {
  final EnvironmentMode environmentMode;
  final bool superuserModeEnabled;
  final FeatureLevel featureLevel;

  const EnvironmentSettings({
    required this.environmentMode,
    required this.superuserModeEnabled,
    this.featureLevel = FeatureLevel.stable,
  });

  // Note: Normally, value objects have dedicated update methods with validation.
  // However, for settings with simple enum/primitive values and no free-text input,
  // a simple copyWith is sufficient and avoids unnecessary boilerplate.
  EnvironmentSettings copyWith({
    EnvironmentMode? environmentMode,
    bool? superuserModeEnabled,
    FeatureLevel? featureLevel,
  }) {
    return EnvironmentSettings(
      environmentMode: environmentMode ?? this.environmentMode,
      superuserModeEnabled: superuserModeEnabled ?? this.superuserModeEnabled,
      featureLevel: featureLevel ?? this.featureLevel,
    );
  }
}
