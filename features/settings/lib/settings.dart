/// The wallet app's settings home, search and navigation.
library;

export 'generated/l10n/settings_localizations.dart' show SettingsLocalizations;
export 'src/domain/settings_failure.dart';
export 'src/presentation/settings_failure_l10n.dart' show SettingsFailureL10n;
export 'src/public/active_network_scope.dart' show ActiveNetworkScope;
export 'src/public/language_locale.dart' show LanguageExtension;
export 'src/public/network_capability_visibility.dart'
    show NetworkCapabilityVisibility;
export 'src/public/support.dart' show Support;
export 'src/settings.dart' show Settings;
export 'src/settings_feature.dart' show SettingsFeature, SettingsNavigation;
export 'src/settings_menu.dart'
    show SettingsEntry, SettingsLabels, SettingsMenu;
export 'src/translation_warning_bottom_sheet.dart'
    show TranslationWarningBottomSheet;
export 'src/ui/settings_route.dart' show SettingsRoute;
export 'src/ui/widgets/superuser_tap_unlocker.dart'
    show SuperuserTapUnlocker, SevenTapUnlocker;
export 'src/ui/widgets/statistics_consent_switch.dart'
    show StatisticsConsentSwitch;
