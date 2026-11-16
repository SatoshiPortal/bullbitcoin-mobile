import 'package:bull_pricer/bull_pricer.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullLanguagePicker,
        BullPickerChip,
        BullPickerItem,
        BullSettingsEntryItem,
        BullSwitch,
        BullText;

/// Settings page of the wizard, built from the controls of the app settings:
/// switches for dark mode and the exchange, menus for the language and the
/// default currency.
class CustomizeStep extends StatelessWidget {
  const CustomizeStep({
    super.key,
    required this.exchangeAccess,
    required this.language,
    required this.defaultCurrency,
    required this.onThemePicked,
    required this.onExchangePicked,
    required this.onLanguagePicked,
    required this.onCurrencyPicked,
  });

  /// `null` hides the exchange row, where the platform does not allow it.
  final bool? exchangeAccess;
  final Language language;
  final String defaultCurrency;
  final ValueChanged<AppThemeMode> onThemePicked;
  final ValueChanged<bool> onExchangePicked;
  final ValueChanged<Language> onLanguagePicked;
  final ValueChanged<String> onCurrencyPicked;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final vGap = Device.screen.height * 0.02;
    final divider = Divider(height: 1, color: context.appColors.border);
    final exchange = exchangeAccess;
    return WizardStepLayout(
      page: WizardPage.customize,
      title: loc.wizardCustomizeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullText(
            loc.wizardCustomizeBody,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          SizedBox(height: vGap),
          MergeSemantics(
            child: BullSettingsEntryItem(
              icon: Icons.dark_mode_outlined,
              title: loc.settingsDarkModeTitle,
              contentPadding: EdgeInsets.zero,
              // Shows the theme in use, as the dark mode switch of the app
              // settings does.
              trailing: BullSwitch(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (dark) => onThemePicked(
                  dark ? AppThemeMode.dark : AppThemeMode.light,
                ),
              ),
            ),
          ),
          if (exchange != null) ...[
            divider,
            MergeSemantics(
              child: BullSettingsEntryItem(
                icon: Icons.currency_exchange,
                title: loc.wizardExchangeTitle,
                subtitle: loc.wizardExchangeDescription,
                contentPadding: EdgeInsets.zero,
                trailing: BullSwitch(
                  value: exchange,
                  onChanged: onExchangePicked,
                ),
              ),
            ),
          ],
          divider,
          BullSettingsEntryItem(
            icon: Icons.language,
            title: loc.settingsLanguageTitle,
            contentPadding: EdgeInsets.zero,
            trailing: BullLanguagePicker<Language>(
              value: language,
              languages: [
                for (final language in Language.values)
                  BullPickerItem(value: language, label: language.label),
              ],
              onChanged: (picked) {
                onLanguagePicked(picked);
                if (picked.isMachineTranslated) {
                  TranslationWarningBottomSheet.show(context);
                }
              },
            ),
          ),
          divider,
          BullSettingsEntryItem(
            icon: Icons.attach_money,
            title: loc.wizardCustomizeDefaultCurrency,
            contentPadding: EdgeInsets.zero,
            trailing: BullPickerChip<String>(
              tooltip: loc.wizardCustomizeDefaultCurrency,
              value: defaultCurrency,
              items: [
                for (final currency in SupportedCurrency.values)
                  BullPickerItem(
                    value: currency.code,
                    label: '${currency.flag} ${currency.code}',
                  ),
              ],
              onChanged: onCurrencyPicked,
            ),
          ),
        ],
      ),
    );
  }
}
