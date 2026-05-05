import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/picker_sheet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';

class CustomizeStep extends StatelessWidget {
  const CustomizeStep({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.themeMode,
    required this.language,
    required this.defaultCurrency,
    required this.onThemePicked,
    required this.onLanguagePicked,
    required this.onCurrencyPicked,
  });

  final int stepIndex;
  final int totalSteps;
  final AppThemeMode themeMode;
  final Language language;
  final String defaultCurrency;
  final ValueChanged<AppThemeMode> onThemePicked;
  final ValueChanged<Language> onLanguagePicked;
  final ValueChanged<String> onCurrencyPicked;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final vGap = Device.screen.height * 0.02;
    return WizardStepLayout(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: loc.wizardCustomizeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            loc.wizardCustomizeBody,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          SizedBox(height: vGap),
          SettingsEntryItem(
            icon: Icons.brightness_6_outlined,
            title: loc.settingsThemeTitle,
            trailing: _TrailingValue(text: _themeLabel(context, themeMode)),
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              final picked = await _showThemeSheet(context, themeMode);
              if (picked != null) onThemePicked(picked);
            },
          ),
          Divider(height: 1, color: context.appColors.border),
          SettingsEntryItem(
            icon: Icons.language,
            title: loc.settingsLanguageTitle,
            trailing: _TrailingValue(text: language.label),
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              final picked = await _showLanguageSheet(context, language);
              if (picked != null) {
                onLanguagePicked(picked);
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
            trailing: _TrailingValue(text: defaultCurrency),
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              final picked = await BlurredBottomSheet.show<String>(
                context: context,
                child: CurrencyBottomSheet(
                  availableCurrencies: CurrencyConstants.supportedFiat,
                  selectedValue: defaultCurrency,
                ),
              );
              if (picked != null) onCurrencyPicked(picked);
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
        BBText(
          text,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: Device.screen.width * 0.01),
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
