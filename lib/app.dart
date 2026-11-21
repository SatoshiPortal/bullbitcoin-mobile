import 'package:bb_mobile/generated/novlang/novlang_bitcoin_price_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_label_editor_localizations.dart';
import 'package:network/setup.dart' show NetworkLocalizations;
import 'package:btc_map/btc_map.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart'
    show SettingsFacade;
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:mempool/mempool.dart';

import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/language_locale.dart'
    show LanguageExtension;
import 'package:bb_mobile/features/settings/ui/widgets/settings_failure_listener.dart';
import 'package:bb_mobile/features/support/public/support_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_announcements_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_quick_actions_localizations.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/features/wallet/public/ark_foreground_setup.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_logs/bull_logs.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_tor/tor_adapter.dart' as tor;
import 'package:bull_ui/bull_ui.dart'
    show BullSupportScope, bullUiLocalizationsDelegate;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:novlang/novlang.dart';

@visibleForTesting
void resumePayjoinsOnAppResume(
  AppLifecycleState state,
  PayjoinLifecycle lifecycle,
) {
  if (state == AppLifecycleState.resumed) {
    unawaited(lifecycle.resume());
  }
}

class BullBitcoinWalletApp extends StatefulWidget {
  const BullBitcoinWalletApp({super.key});

  @override
  State<BullBitcoinWalletApp> createState() => _BullBitcoinWalletAppState();
}

class _BullBitcoinWalletAppState extends State<BullBitcoinWalletApp> {
  late final AppLifecycleListener _listener;
  late final tor.TorLifecycleController _torLifecycleController;
  // final router = AppRouter.router;

  @override
  void initState() {
    super.initState();

    _torLifecycleController = locator<tor.TorLifecycleController>()..start();
    // Initialize the AppLifecycleListener class and pass callbacks
    _listener = AppLifecycleListener(onStateChange: _onStateChanged);
  }

  @override
  void dispose() {
    // Do not forget to dispose the listener
    _listener.dispose();
    if (locator.isRegistered<PayjoinLifecycle>()) {
      unawaited(locator<PayjoinLifecycle>().dispose());
    }
    _torLifecycleController.dispose();

    super.dispose();
  }

  // Wallet/swap sync on resume is handled by SyncCoordinator's own
  // AppLifecycleListener — see lib/features/wallet/data/sync_coordinator.dart.
  void _onStateChanged(AppLifecycleState state) {
    log.info(state.name);
    if (locator.isRegistered<PayjoinLifecycle>()) {
      resumePayjoinsOnAppResume(state, locator<PayjoinLifecycle>());
    }
    if (state == AppLifecycleState.resumed &&
        locator.isRegistered<ArkForegroundHost>()) {
      unawaited(locator<ArkForegroundHost>().resume());
    }
    // iOS lifecycle is `active → inactive → hidden → paused`. The user can
    // force-quit from the app switcher during `inactive` and skip both the
    // `hidden` and `paused` flushes, so flush there too.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      log.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    Device.init(context);

    final app = MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => locator<SettingsCubit>()..init()),
        BlocProvider(
          create: (_) =>
              locator<AppStartupBloc>()..add(const AppStartupStarted()),
        ),
        // Make the wallet bloc available to the whole app so environment changes
        // from anywhere (wallet or exchange tab) can trigger a re-fetch of the wallets.
        BlocProvider(create: (_) => locator<WalletBloc>()),
      ],
      child: ExchangeScope(
        child: MultiBlocListener(
          listeners: [
            SettingsFailureListener(),
            BlocListener<AppStartupBloc, AppStartupState>(
              listenWhen: (previous, current) =>
                  previous != current &&
                  current is AppStartupSuccess &&
                  current.hasDefaultWallets,
              listener: (context, settings) async {
                // If wallets exist and the app has started successfully,
                // we can start the wallet bloc to fetch the wallets.
                context.read<WalletBloc>().add(const WalletStarted());
                final _ = await locator<ExchangeFacade>().resolveAccess();
              },
            ),
            BlocListener<SettingsCubit, SettingsState>(
              listenWhen: (previous, current) =>
                  previous.environment != null &&
                  previous.environment != current.environment,
              listener: (context, settings) async {
                // Ark pages must not act for the previous network's wallet.
                if (locator.isRegistered<ArkForegroundHost>()) {
                  locator<ArkForegroundHost>().invalidate();
                }
                context.read<WalletBloc>().add(const WalletStarted());
                final _ = await locator<ExchangeFacade>().resolveAccess();
              },
            ),
          ],
          child:
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
                builder: (context, data) {
                  final (language, themeMode, isSuperuser) = data;
                  final novlangPolicy = resolveNovlangPolicy(
                    defaultTargetPlatform,
                    isSuperuser,
                  );
                  final systemBrightness = MediaQuery.platformBrightnessOf(
                    context,
                  );
                  final effectiveThemeMode = themeMode ?? AppThemeMode.system;

                  late final AppThemeType appThemeType;
                  switch (effectiveThemeMode) {
                    case AppThemeMode.light:
                      appThemeType = AppThemeType.light;
                    case AppThemeMode.dark:
                      appThemeType = AppThemeType.dark;
                    case AppThemeMode.system:
                      appThemeType = systemBrightness == .dark
                          ? AppThemeType.dark
                          : AppThemeType.light;
                  }

                  return RepositoryProvider<MempoolLinks>.value(
                    value: locator<Mempool>().links,
                    child: MaterialApp.router(
                      title: 'BullBitcoin Wallet',
                      debugShowCheckedModeBanner: kDebugMode,
                      routerConfig: AppRouter.router,
                      theme: AppTheme.themeData(appThemeType),
                      locale: language?.locale,
                      localizationsDelegates: [
                        NovlangLabelEditorLocalizationsDelegate(novlangPolicy),
                        NovlangAnnouncementsLocalizationsDelegate(
                          novlangPolicy,
                        ),
                        NovlangBitcoinPriceLocalizationsDelegate(novlangPolicy),
                        ...novlangLocalizationsDelegates(novlangPolicy),
                        LogsLocalizations.delegate,
                        NetworkLocalizations.delegate,
                        BtcMapFeature.localizationsDelegate,
                        NovlangQuickActionsLocalizationsDelegate(
                          novlangPolicy,
                          const QuickActionsFallbackDelegate(),
                        ),
                        bullUiLocalizationsDelegate,
                        ...RecoverBullFeature.localizationsDelegates,
                      ],
                      supportedLocales: AppLocalizations.supportedLocales,
                      builder: (context, child) {
                        if (child == null) return const SizedBox.shrink();
                        // keyboard_actions still uses SDK Material widgets;
                        // the official bridge supports this transition.
                        // ignore: deprecated_member_use
                        final app = MaterialUiCompatibilityBridge(
                          child: SettingsFacade.amountScope(
                            navigatorKey: AppRouter.rootNavigatorKey,
                            child: BullSupportScope(
                              onContactSupport: SupportFacade.contactSupport,
                              child: AppStartupWidget(
                                app: locator<RecoverBullFeature>().withAlerts(
                                  child,
                                  onOpen: () => AppRouter.router.pushNamed(
                                    'recoverbullFlows',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                        // Mark beta-channel builds (`make android beta`) with a
                        // corner banner. Release mode drops the Flutter debug
                        // banner, so this is how testers tell beta from production.
                        if (appFlavor != 'beta') return app;
                        return Banner(
                          message: 'BETA',
                          location: BannerLocation.topEnd,
                          color: Theme.of(context).colorScheme.error,
                          child: app,
                        );
                      },
                    ),
                  );
                },
              ),
        ),
      ),
    );
    return locator<BitcoinPriceFeature>().providePrices(child: app);
  }
}
