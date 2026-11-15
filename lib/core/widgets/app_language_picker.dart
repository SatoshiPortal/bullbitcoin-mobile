import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The app language as a [BullPickerChip], shared across the app (wizard, app
/// settings, onboarding advanced options). Any non-English pick shows
/// [TranslationWarningBottomSheet], once per app session.
class AppLanguagePicker extends StatelessWidget {
  const AppLanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final Language value;
  final ValueChanged<Language> onChanged;

  /// Drops the border and the globe, for a settings row that already shows
  /// both a title and the globe.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BullPickerChip<Language>(
      icon: compact ? null : Icons.language,
      outlined: !compact,
      value: value,
      items: [
        for (final language in Language.values)
          BullPickerItem(value: language, label: language.label),
      ],
      onChanged: (picked) {
        onChanged(picked);
        if (picked != Language.unitedStatesEnglish) {
          TranslationWarningBottomSheet.show(context);
        }
      },
    );
  }
}
