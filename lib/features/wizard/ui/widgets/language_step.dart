import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/widgets/app_language_picker.dart';
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
    return Center(
      child: AppLanguagePicker(value: selected, onChanged: onChanged),
    );
  }
}
