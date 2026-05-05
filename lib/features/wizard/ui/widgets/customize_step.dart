import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/picker_sheet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:bb_mobile/features/wizard/wizard_choices.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Hardcoded list shown in the wizard. Limited to currencies fully
/// supported by [CurrencyBottomSheet]'s flag/name lookup. The full dynamic
/// list (fetched from the exchange API via the locator) becomes available
/// once the user reaches the main app's settings page.
const List<String> kWizardCurrencies = [
  'USD',
  'EUR',
  'CAD',
  'MXN',
  'CRC',
  'ARS',
  'COP',
];

class CustomizeStep extends StatelessWidget {
  const CustomizeStep({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.choices,
    required this.onChange,
  });

  final int stepIndex;
  final int totalSteps;
  final WizardChoices choices;
  final ValueChanged<WizardChoices> onChange;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return WizardStepLayout(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: loc.wizardCustomizeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.wizardCustomizeBody,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const Gap(16),
          SettingsEntryItem(
            icon: Icons.brightness_6_outlined,
            title: loc.settingsThemeTitle,
            trailing: _TrailingValue(
              text: _themeLabel(context, choices.themeMode),
            ),
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              final picked = await _showThemeSheet(context, choices.themeMode);
              if (picked != null) {
                onChange(choices.copyWith(themeMode: picked));
              }
            },
          ),
          Divider(height: 1, color: context.appColors.border),
          SettingsEntryItem(
            icon: Icons.language,
            title: loc.settingsLanguageTitle,
            trailing: _TrailingValue(text: choices.language.label),
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              final picked = await _showLanguageSheet(
                context,
                choices.language,
              );
              if (picked != null) {
                onChange(choices.copyWith(language: picked));
                if (picked != Language.unitedStatesEnglish && context.mounted) {
                  TranslationWarningBottomSheet.show(context);
                }
              }
            },
          ),
          Divider(height: 1, color: context.appColors.border),
          SettingsEntryItem(
            icon: Icons.attach_money,
            title: loc.wizardCustomizeDefaultCurrency,
            trailing: _TrailingValue(text: choices.defaultCurrency),
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              final picked = await BlurredBottomSheet.show<String>(
                context: context,
                child: CurrencyBottomSheet(
                  availableCurrencies: kWizardCurrencies,
                  selectedValue: choices.defaultCurrency,
                ),
              );
              if (picked != null) {
                onChange(choices.copyWith(defaultCurrency: picked));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TrailingValue extends StatelessWidget {
  const _TrailingValue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(4),
        Icon(Icons.chevron_right, color: context.appColors.onSurface),
      ],
    );
  }
}

String _themeLabel(BuildContext context, AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return context.loc.themeLight;
    case AppThemeMode.dark:
      return context.loc.themeDark;
    case AppThemeMode.system:
      return context.loc.themeSystem;
  }
}

// Wizard intentionally exposes only Light + Dark — System is omitted per
// product decision. Default for the wizard is set explicitly to match the
// device brightness in `WizardScreen.initState`, so `themeMode == system`
// should never be the rendered state by the time this sheet is opened.
const List<AppThemeMode> _wizardThemeModes = [
  AppThemeMode.light,
  AppThemeMode.dark,
];

Future<AppThemeMode?> _showThemeSheet(
  BuildContext context,
  AppThemeMode current,
) {
  return BlurredBottomSheet.show<AppThemeMode>(
    context: context,
    child: BBPickerSheet<AppThemeMode>(
      title: context.loc.settingsThemeTitle,
      options: _wizardThemeModes,
      isSelected: (mode) => mode == current,
      label: (mode) => _themeLabel(context, mode),
    ),
  );
}

Future<Language?> _showLanguageSheet(BuildContext context, Language current) {
  return BlurredBottomSheet.show<Language>(
    context: context,
    child: BBPickerSheet<Language>(
      title: context.loc.settingsLanguageTitle,
      options: Language.values,
      isSelected: (lang) => lang == current,
      label: (lang) => lang.label,
    ),
  );
}
