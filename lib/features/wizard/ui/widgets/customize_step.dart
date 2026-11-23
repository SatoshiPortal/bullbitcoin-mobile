import 'package:bull_pricer/bull_pricer.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart'
    show TranslationWarningBottomSheet;
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
        BullText,
        BullTypographyX;

/// Settings page of the wizard, built from the controls of the app settings:
/// menus for the language and the default currency, switches for dark mode,
/// the exchange and background tasks, then notifications once background
/// tasks are on.
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
    required this.backgroundTasks,
    required this.onBackgroundTasksPicked,
    required this.notificationsAllowed,
    required this.notificationsRefused,
    required this.onNotificationsPicked,
  });

  /// `null` hides the exchange row, where the platform does not allow it.
  final bool? exchangeAccess;
  final Language language;
  final String defaultCurrency;
  final ValueChanged<AppThemeMode> onThemePicked;
  final ValueChanged<bool> onExchangePicked;
  final ValueChanged<Language> onLanguagePicked;
  final ValueChanged<String> onCurrencyPicked;

  /// `null` hides background tasks and notifications, where the platform
  /// cannot run them.
  final bool? backgroundTasks;
  final ValueChanged<bool> onBackgroundTasksPicked;

  /// Read from the system.
  final bool notificationsAllowed;

  /// The system turned down the request: only its settings can grant it.
  final bool notificationsRefused;
  final ValueChanged<bool> onNotificationsPicked;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final vGap = Device.screen.height * 0.02;
    final divider = Divider(height: 1, color: context.appColors.border);
    final exchange = exchangeAccess;
    final background = backgroundTasks;
    return WizardStepLayout(
      page: WizardPage.customize,
      title: loc.wizardCustomizeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullText(
            loc.wizardCustomizeBody,
            style: context.bullType.body.copyWith(
              color: context.appColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          SizedBox(height: vGap),
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
          divider,
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
          if (background != null) ...[
            divider,
            MergeSemantics(
              child: BullSettingsEntryItem(
                icon: Icons.sync,
                title: loc.backgroundTasksTitle,
                subtitle: loc.wizardBackgroundTasksDescription,
                contentPadding: EdgeInsets.zero,
                trailing: BullSwitch(
                  value: background,
                  onChanged: onBackgroundTasksPicked,
                ),
              ),
            ),
            if (background) ...[
              divider,
              MergeSemantics(
                child: BullSettingsEntryItem(
                  icon: Icons.notifications_none,
                  title: loc.notificationsTitle,
                  subtitle: notificationsRefused
                      ? loc.blockedInSystemSettings
                      : loc.wizardNotificationsDescription,
                  contentPadding: EdgeInsets.zero,
                  trailing: BullSwitch(
                    value: notificationsAllowed,
                    onChanged: onNotificationsPicked,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
