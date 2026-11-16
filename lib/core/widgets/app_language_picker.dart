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
  });

  final Language value;
  final ValueChanged<Language> onChanged;

  @override
  Widget build(BuildContext context) {
    return BullPickerChip<Language>(
      icon: Icons.language,
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
