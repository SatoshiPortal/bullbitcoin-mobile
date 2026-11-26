/// Fixtures for exercising Settings in isolation or in an app host.
library;

import 'package:material_ui/material_ui.dart';

import 'generated/l10n/settings_localizations.dart';

export 'generated/l10n/settings_localizations.dart';
export 'src/presentation/settings_search.dart' show searchSettings;
export 'src/data/background_preferences_repository_impl.dart';
export 'src/data/payjoin_disclaimer_repository_impl.dart';
export 'src/data/recoverbull_settings_adapter.dart';
export 'src/domain/regtest_recoverbull_profile.dart';
export 'src/domain/repositories/background_preferences_repository.dart';
export 'src/domain/repositories/payjoin_disclaimer_repository.dart';
export 'src/domain/settings_failure.dart';
export 'src/domain/usecases/background_preferences_usecase.dart';
export 'src/domain/usecases/check_sp_wallet_setup_for_settings_usecase.dart';
export 'src/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
export 'src/domain/usecases/load_settings_usecase.dart';
export 'src/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
export 'src/domain/usecases/revoke_sp_wallet_for_settings_usecase.dart';
export 'src/domain/usecases/set_active_network_usecase.dart';
export 'src/domain/usecases/set_amount_input_mode_usecase.dart';
export 'src/domain/usecases/set_bitcoin_unit_usecase.dart';
export 'src/domain/usecases/set_currency_usecase.dart';
export 'src/domain/usecases/set_environment_usecase.dart';
export 'src/domain/usecases/set_error_reporting_usecase.dart';
export 'src/domain/usecases/set_exchange_testnet_basic_auth_usecase.dart';
export 'src/domain/usecases/set_hide_amounts_usecase.dart';
export 'src/domain/usecases/set_is_dev_mode_usecase.dart';
export 'src/domain/usecases/set_is_superuser_usecase.dart';
export 'src/domain/usecases/set_language_usecase.dart';
export 'src/domain/usecases/set_payjoin_enabled_usecase.dart';
export 'src/domain/usecases/set_payjoin_expire_after_sec_usecase.dart';
export 'src/domain/usecases/set_payjoin_min_amount_usecase.dart';
export 'src/domain/usecases/set_screen_capture_protection_usecase.dart';
export 'src/domain/usecases/set_show_payment_animations_usecase.dart';
export 'src/domain/usecases/set_theme_mode_usecase.dart';
export 'src/domain/usecases/sync_exchange_currency_usecase.dart';
export 'src/domain/usecases/watch_payjoin_policy_usecase.dart';
export 'src/presentation/bloc/background_preferences_cubit.dart';
export 'src/presentation/bloc/settings_cubit.dart';
export 'src/presentation/settings_failure_l10n.dart';
export 'src/public/support_links.dart';
export 'src/ui/screens/app_settings/app_settings_screen.dart';
export 'src/ui/screens/app_settings/permissions_screen.dart';
export 'src/ui/screens/bitcoin/payjoin_advanced_settings_screen.dart';
export 'src/ui/screens/bitcoin/payjoin_settings_screen.dart';
export 'src/ui/screens/bitcoin/wallet_settings_screen.dart';
export 'src/ui/settings_item.dart';
export 'src/ui/widgets/amount_input_mode_setting.dart';
export 'src/ui/widgets/ark_debug_notification.dart';
export 'src/ui/widgets/dark_mode_switch.dart';
export 'src/ui/widgets/dev_mode_switch.dart';
export 'src/ui/widgets/error_reporting_confirmation_bottom_sheet.dart';
export 'src/ui/widgets/error_reporting_switch.dart';
export 'src/ui/widgets/exchange_testnet_basic_auth_dialog.dart';
export 'src/ui/widgets/screen_capture_protection_switch.dart';
export 'src/ui/widgets/settings_failure_listener.dart';
export 'src/ui/widgets/superuser_tap_unlocker.dart';
export 'src/ui/widgets/testnet_mode_switch.dart';

const settingsTestLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  SettingsLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
