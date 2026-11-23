import 'domain/usecases/background_preferences_usecase.dart';
import 'presentation/bloc/background_preferences_cubit.dart';
import 'background_setup.dart';
import 'ui/settings_route.dart';
import 'data/payjoin_disclaimer_repository_impl.dart';
import 'ui/widgets/settings_failure_listener.dart';
import 'ui/screens/app_settings/app_settings_screen.dart';
import 'ui/screens/app_settings/permissions_screen.dart';
import 'ui/screens/bitcoin/payjoin_advanced_settings_screen.dart';
import 'ui/screens/bitcoin/wallet_settings_screen.dart';
import 'ui/screens/bitcoin/payjoin_settings_screen.dart';
import 'domain/usecases/sync_exchange_currency_usecase.dart';
import 'domain/usecases/load_settings_usecase.dart';
import 'domain/usecases/set_theme_mode_usecase.dart';
import 'domain/usecases/set_screen_capture_protection_usecase.dart';
import 'domain/usecases/set_currency_usecase.dart';
import 'domain/usecases/set_exchange_testnet_basic_auth_usecase.dart';
import 'domain/usecases/set_hide_amounts_usecase.dart';
import 'domain/usecases/revoke_sp_wallet_for_settings_usecase.dart';
import 'domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
import 'domain/usecases/set_bitcoin_unit_usecase.dart';
import 'domain/usecases/set_environment_usecase.dart';
import 'domain/usecases/set_is_dev_mode_usecase.dart';
import 'domain/usecases/check_sp_wallet_setup_for_settings_usecase.dart';
import 'domain/usecases/set_payjoin_min_amount_usecase.dart';
import 'domain/usecases/set_is_superuser_usecase.dart';
import 'domain/usecases/set_amount_input_mode_usecase.dart';
import 'domain/usecases/set_language_usecase.dart';
import 'domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'domain/usecases/set_error_reporting_usecase.dart';
import 'domain/usecases/set_payjoin_expire_after_sec_usecase.dart';

import 'dart:async';

import 'package:provider/single_child_widget.dart';
import 'package:silent/silent.dart';
import 'package:preferences/preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:exchange/exchange.dart';
import 'package:electrum/setup.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:settings/src/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:settings/src/domain/usecases/watch_payjoin_policy_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

part 'ui/amount_preferences_binder.dart';

/// Public settings contract consumed by other features.
class Settings {
  /// Captures the active environment when a new account journey starts.
  static NetworkEnv? networkOf(BuildContext context) => context.select(
    (SettingsCubit cubit) => cubit.state.environment?.networkEnv,
  );

  static Future<void> toggleAmountVisibility(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final settings = cubit.state.storedSettings;
    if (settings == null) return;
    await cubit.toggleHideAmounts(!(settings.hideAmounts ?? true));
  }

  static Future<void> setAmountsHidden(BuildContext context, bool hide) async {
    final cubit = context.read<SettingsCubit>();
    final settings = cubit.state.storedSettings;
    if (settings == null) return;
    await cubit.toggleHideAmounts(hide);
  }

  static Future<void> changeDisplayCurrency(
    BuildContext context,
    String currencyCode,
  ) => context.read<SettingsCubit>().changeCurrency(currencyCode);

  static Widget amountScope({
    required Widget child,
    required GlobalKey<NavigatorState> navigatorKey,
  }) => _AmountPreferencesBinder(navigatorKey: navigatorKey, child: child);

  final SetPayjoinEnabledUsecase _setPayjoinEnabledUsecase;
  final WatchPayjoinPolicyUsecase _watchPayjoinPolicyUsecase;
  final SettingsCubit Function() _createCubit;
  final BackgroundPreferencesUsecase _backgroundPreferences;
  SettingsCubit? _state;

  Settings._(
    this._setPayjoinEnabledUsecase,
    this._watchPayjoinPolicyUsecase,
    this._createCubit,
    this._backgroundPreferences,
  );

  static Settings open({
    required Preferences preferences,
    required ElectrumDefaultsProvisioner electrum,
    required Exchange exchange,
    required Silent silent,
    required PayjoinPolicyAccess payjoin,
    required BackgroundSchedule backgroundSchedule,
    required String notificationChannelId,
  }) {
    final disclaimer = PayjoinDisclaimerRepositoryImpl();
    final setPayjoinEnabled = SetPayjoinEnabledUsecase(
      payjoinPolicy: payjoin,
      getPayjoinDisclaimerShownUsecase: GetPayjoinDisclaimerShownUsecase(
        payjoinDisclaimerRepository: disclaimer,
      ),
      markPayjoinDisclaimerShownUsecase: MarkPayjoinDisclaimerShownUsecase(
        payjoinDisclaimerRepository: disclaimer,
      ),
    );
    final watchPayjoinPolicy = WatchPayjoinPolicyUsecase(payjoin);
    return Settings._(
      setPayjoinEnabled,
      watchPayjoinPolicy,
      () => SettingsCubit(
        loadPreferencesUsecase: LoadSettingsUsecase(preferences),
        setEnvironmentUsecase: SetEnvironmentUsecase(
          settingsRepository: preferences,
          electrumSettings: electrum,
        ),
        setAmountInputModeUsecase: SetAmountInputModeUsecase(preferences),
        setBitcoinUnitUsecase: SetBitcoinUnitUsecase(
          settingsRepository: preferences,
        ),
        setLanguageUsecase: SetLanguageUsecase(settingsRepository: preferences),
        setCurrencyUsecase: SetCurrencyUsecase(settingsRepository: preferences),
        syncExchangeCurrencyUsecase: SyncExchangeCurrencyUsecase(
          settingsRepository: preferences,
          exchange: exchange,
        ),
        setHideAmountsUsecase: SetHideAmountsUsecase(
          settingsRepository: preferences,
        ),
        setIsSuperuserUsecase: SetIsSuperuserUsecase(
          settingsRepository: preferences,
        ),
        setIsDevModeUsecase: SetIsDevModeUsecase(
          settingsRepository: preferences,
        ),
        setThemeModeUsecase: SetThemeModeUsecase(
          settingsRepository: preferences,
        ),
        revokeSpWalletUsecase: RevokeSpWalletForSettingsUsecase(silent: silent),
        checkSpWalletSetupUsecase: CheckSpWalletSetupForSettingsUsecase(
          silent: silent,
        ),
        setErrorReportingUsecase: SetErrorReportingUsecase(
          settingsRepository: preferences,
        ),
        setScreenCaptureProtectionUsecase: SetScreenCaptureProtectionUsecase(
          settingsRepository: preferences,
        ),
        setExchangeTestnetBasicAuthUsecase: SetExchangeTestnetBasicAuthUsecase(
          preferences: preferences,
        ),
        setPayjoinEnabledUsecase: setPayjoinEnabled,
        watchPayjoinPolicyUsecase: watchPayjoinPolicy,
        setPayjoinMinAmountUsecase: SetPayjoinMinAmountUsecase(
          payjoinPolicy: payjoin,
        ),
        setPayjoinExpireAfterSecUsecase: SetPayjoinExpireAfterSecUsecase(
          payjoinPolicy: payjoin,
        ),
      ),
      createBackgroundPreferences(
        backgroundSchedule,
        notificationChannelId: notificationChannelId,
      ),
    );
  }

  SettingsCubit get _cubit => _state ??= _createCubit();

  Future<void> close() async {
    final state = _state;
    if (state != null && !state.isClosed) await state.close();
  }

  bool get isSuperuser => _cubit.state.isSuperuser ?? false;

  Stream<bool> watchSuperuser() => _cubit.stream
      .where((state) => state.storedSettings != null)
      .map((state) => state.isSuperuser ?? false);

  Widget provide({required Widget child}) => BlocProvider<SettingsCubit>(
    create: (_) {
      final cubit = _cubit;
      unawaited(cubit.init());
      return cubit;
    },
    child: child,
  );

  static SingleChildWidget failureListener({
    required OverlayState? Function() resolveOverlay,
  }) => SettingsFailureListener(resolveOverlay: resolveOverlay);

  static SingleChildWidget onEnvironmentChanged({
    required void Function(BuildContext context) onChanged,
  }) => BlocListener<SettingsCubit, SettingsState>(
    listenWhen: (previous, current) =>
        previous.environment != null &&
        previous.environment != current.environment,
    listener: (context, _) => onChanged(context),
  );

  static Widget appearance({
    required Widget Function(BuildContext, (Language?, AppThemeMode?, bool?))
    builder,
  }) =>
      BlocSelector<
        SettingsCubit,
        SettingsState,
        (Language?, AppThemeMode?, bool?)
      >(
        selector: (settings) => (
          settings.language,
          settings.storedSettings?.themeMode,
          settings.isSuperuser,
        ),
        builder: builder,
      );

  static Language? languageOf(BuildContext context) =>
      context.select((SettingsCubit cubit) => cubit.state.language);

  static Future<void> changeLanguage(BuildContext context, Language language) =>
      context.read<SettingsCubit>().changeLanguage(language);

  static bool isSuperuserOf(BuildContext context) =>
      context.select((SettingsCubit cubit) => cubit.state.isSuperuser ?? false);

  static ({Environment? environment, bool isSuperuser, bool isDevModeEnabled})
  readEnvironment(BuildContext context) {
    final state = context.read<SettingsCubit>().state;
    return (
      environment: state.environment,
      isSuperuser: state.isSuperuser ?? false,
      isDevModeEnabled: state.isDevModeEnabled ?? false,
    );
  }

  static List<RouteBase> walletRoutes() => [
    GoRoute(
      name: SettingsRoute.walletSettings.name,
      path: SettingsRoute.walletSettings.path,
      builder: (_, _) => const WalletSettingsScreen(),
    ),
    GoRoute(
      name: SettingsRoute.payjoinSettings.name,
      path: SettingsRoute.payjoinSettings.path,
      builder: (_, _) => const PayjoinSettingsScreen(),
    ),
    GoRoute(
      name: SettingsRoute.payjoinAdvancedSettings.name,
      path: SettingsRoute.payjoinAdvancedSettings.path,
      builder: (_, _) => const PayjoinAdvancedSettingsScreen(),
    ),
  ];

  static GoRoute appSettingsRoute(
    List<RouteBase> routes, {
    required Settings Function() settings,
  }) => GoRoute(
    name: SettingsRoute.appSettings.name,
    path: SettingsRoute.appSettings.path,
    builder: (_, _) => const AppSettingsScreen(),
    routes: [
      ...routes,
      GoRoute(
        name: SettingsRoute.permissions.name,
        path: SettingsRoute.permissions.path,
        builder: (_, _) => BlocProvider(
          create: (_) =>
              BackgroundPreferencesCubit(settings()._backgroundPreferences)
                ..load(),
          child: const PermissionsScreen(),
        ),
      ),
    ],
  );

  /// Payjoin when receiving from other users, behind the disclaimer.
  Future<Result<bool, SettingsFailure>> setPayjoinReceiveEnabled(
    bool enabled, {
    required Future<bool> Function() requestConsent,
  }) => _setPayjoinEnabledUsecase.execute(
    PayjoinAction.receive,
    enabled,
    requestConsent: requestConsent,
  );

  Stream<({bool receiveEnabled, int minimumAmountSat})>
  watchPayjoinReceivePolicy() {
    return _watchPayjoinPolicyUsecase.execute().map(
      (policy) => (
        receiveEnabled: policy.receiveEnabled,
        minimumAmountSat: policy.minimumAmount.value.toInt(),
      ),
    );
  }

  Stream<int> watchPayjoinMinAmount() => watchPayjoinReceivePolicy()
      .map((policy) => policy.minimumAmountSat)
      .distinct();

  Stream<bool> watchPayjoinReceiveEnabled() => watchPayjoinReceivePolicy()
      .map((policy) => policy.receiveEnabled)
      .distinct();
}
