import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:flutter/widgets.dart';

/// User-facing label for each [FeeratePreset]. Keeps the sat/vB values in
/// domain and maps them to localized labels in the presentation layer.
extension FeeratePresetL10n on FeeratePreset {
  String label(BuildContext context) => switch (this) {
    FeeratePreset.slow => context.loc.spFeeratePresetSlow,
    FeeratePreset.normal => context.loc.spFeeratePresetNormal,
    FeeratePreset.fast => context.loc.spFeeratePresetFast,
  };
}
