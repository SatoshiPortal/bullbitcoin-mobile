import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// A compact bordered language picker shared across the app (wizard, app
/// settings, onboarding advanced options). Displays a chip with a globe
/// icon, the selected language's native label, and a dropdown arrow; tapping
/// opens a `PopupMenu` with every language.
///
/// The trailing label is width-constrained so long native names never push
/// the surrounding row's title onto multiple lines. Fires [onChanged] on
/// selection and automatically shows [TranslationWarningBottomSheet] on any
/// non-English pick — the warning is idempotent per app session.
class AppLanguagePicker extends StatelessWidget {
  const AppLanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Language value;
  final ValueChanged<Language> onChanged;

  static const double _maxLabelWidth = 120;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<Language>(
      initialValue: value,
      constraints: const BoxConstraints(maxHeight: 400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => Language.values
          .map(
            (l) => PopupMenuItem<Language>(
              value: l,
              child: Text(
                l.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: l == value
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          )
          .toList(),
      onSelected: (picked) {
        onChanged(picked);
        if (picked != Language.unitedStatesEnglish) {
          TranslationWarningBottomSheet.show(context);
        }
      },
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(color: theme.colorScheme.outline),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxLabelWidth),
                child: Text(
                  value.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}
