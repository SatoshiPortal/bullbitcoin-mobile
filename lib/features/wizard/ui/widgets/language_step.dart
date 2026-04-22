import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:flutter/material.dart';

class LanguageStep extends StatelessWidget {
  const LanguageStep({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Language selected;
  final ValueChanged<Language> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Language>(
      initialValue: selected,
      isExpanded: true,
      items: Language.values
          .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
        if (v != Language.unitedStatesEnglish) {
          TranslationWarningBottomSheet.show(context);
        }
      },
    );
  }
}
