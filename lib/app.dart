import 'package:access/access.dart'
    show Access, AccessPrivacyVeil, AppUnlockRouteData;
import 'package:send/setup.dart' show SendLocalizations;
import 'package:coins/setup.dart' show CoinsLocalizations;
import 'package:send/send.dart' show Consolidation;
import 'package:spend/spend.dart' show Spend;
import 'package:startup/setup.dart';
import 'package:bb_mobile/generated/novlang/novlang_all_seed_view_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_bull_exchange_localizations.dart';
import 'package:bip85/bip85.dart';
import 'package:address_view/routes.dart' show AddressViewLocalizations;
import 'package:backups/backups.dart';
import 'package:backup_metadata/backup_metadata_ui.dart'
    show backupMetadataLocalizationsDelegate;
import 'package:backup_metadata/setup.dart' show BackupMetadataFeature;
import 'package:bb_mobile/generated/novlang/novlang_bitcoin_price_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_label_editor_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_receive_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_settings_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_swap_localizations.dart';
import 'package:network/setup.dart' show NetworkLocalizations;
import 'package:bull_exchange/bull_exchange.dart' show ExchangeSessionScope;
import 'package:btc_map/btc_map.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:mempool/mempool.dart';

import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:exchange/exchange.dart' show Exchange;
import 'package:bull_ui/app_theme.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:settings/settings.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_announcements_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_quick_actions_localizations.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network_banner.dart';
import 'package:startup/startup.dart';
import 'package:bb_mobile/router.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_reporting/statistics.dart';
import 'package:bull_logs/bull_logs.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_tor/tor_adapter.dart' as tor;
import 'package:bull_ui/bull_ui.dart'
    show BullSupportScope, bullUiLocalizationsDelegate;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart' show GoRouter;
import 'package:novlang/novlang.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/setup.dart';

@visibleForTesting
void resumePayjoinsOnAppResume(
  AppLifecycleState state,
  ForegroundWalletStartup startup,
) {
  if (state == AppLifecycleState.resumed) {
    startup.resumePayjoins();
  }
}

@visibleForTesting
AppUnlockRouteData returnAfterWalletUnlock(
  GoRouter router,
  Uri destination,
  ForegroundWalletStartup startup,
) => AppUnlockRouteData(
  onSuccess: () {
    startup.confirmUnlock();
    router.go(destination.toString());
  },
);

class BullBitcoinWalletApp extends StatefulWidget {
  const BullBitcoinWalletApp({super.key});

  @override
  State<BullBitcoinWalletApp> createState() => _BullBitcoinWalletAppState();
}

class _BullBitcoinWalletAppState extends State<BullBitcoinWalletApp> {
  late final AppLifecycleListener _listener;
  late final tor.TorLifecycleController _torLifecycleController;
  StreamSubscription<bool>? _lockSubscription;
  var _locked = false;

  @override
  void initState() {
    super.initState();
    if (locator.isRegistered<Access>()) {
      _lockSubscription = locator<Access>().locked.listen(_onLockChanged);
    }

    _torLifecycleController = locator<tor.TorLifecycleController>()..start();
    // Initialize the AppLifecycleListener class and pass callbacks
    _listener = AppLifecycleListener(onStateChange: _onStateChanged);
    final state = WidgetsBinding.instance.lifecycleState;
    Statistics.instance.setForeground(
      state == null || state == AppLifecycleState.resumed,
    );
  }

  @override
  void dispose() {
    // Do not forget to dispose the listener
    _listener.dispose();
    Statistics.instance.setForeground(false);
    unawaited(_lockSubscription?.cancel());
    if (locator.isRegistered<PayjoinLifecycle>()) {
      unawaited(locator<PayjoinLifecycle>().dispose());
    }
    _torLifecycleController.dispose();

    super.dispose();
  }

  /// On lock the unlock screen replaces the current page; the PIN brings the
  /// user back to the location they left. Engines that sign or reveal are
  /// suspended on lock and resumed once on unlock (D93).
  void _onLockChanged(bool locked) {
    _locked = locked;
    if (locator.isRegistered<ForegroundWalletStartup>()) {
      locator<ForegroundWalletStartup>().onLockChanged(locked);
    }
    if (!locked) return;
    final router = AppRouter.router;
    final here = router.routerDelegate.currentConfiguration.uri;
    if (here.path == AppUnlockRouteData.path) return;
    final unlock = locator.isRegistered<ForegroundWalletStartup>()
        ? returnAfterWalletUnlock(
            router,
            here,
            locator<ForegroundWalletStartup>(),
          )
        : AppUnlockRouteData(onSuccess: () => router.go(here.toString()));
    unlock.go(router);
  }

  // Overview schedules its own resume sync through its lifecycle listener.
  void _onStateChanged(AppLifecycleState state) {
    Statistics.instance.setForeground(state == AppLifecycleState.resumed);
    log.info(state.name);
    if (locator.isRegistered<Access>()) {
      locator<Access>().onLifecycle(state);
    }
    // A locked app resumes no engine: they would only be refused by Secrets.
    if (!_locked && locator.isRegistered<ForegroundWalletStartup>()) {
      resumePayjoinsOnAppResume(state, locator<ForegroundWalletStartup>());
    }
    if (!_locked &&
        state == AppLifecycleState.resumed &&
        locator.isRegistered<BackupMetadataFeature>()) {
      unawaited(locator<BackupMetadataFeature>().trigger.onResumed());
    }
    if (!_locked &&
        state == AppLifecycleState.resumed &&
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

    final app = locator<Settings>().provide(
      child: MultiBlocProvider(
        providers: [
          // Make the wallet bloc available to the whole app so environment changes
          // from anywhere (wallet or exchange tab) can trigger a re-fetch of the wallets.
          BlocProvider(create: (_) => locator<WalletBloc>()),
        ],
        child: locator<StartupFeature>().scope(
          onWalletsReady: (context) async {
            context.read<WalletBloc>().add(const WalletStarted());
            final _ = await locator<Exchange>().resolveAccess();
          },
          child: ExchangeSessionScope(
            exchange: () => locator<Exchange>(),
            preferences: () => locator<Preferences>(),
            child: MultiBlocListener(
              listeners: [
                Settings.failureListener(
                  resolveOverlay: () =>
                      AppRouter.rootNavigatorKey.currentState?.overlay,
                ),
                Settings.onEnvironmentChanged(
                  onChanged: (context) async {
                    // Ark pages must not act for the previous network's wallet.
                    if (locator.isRegistered<ArkForegroundHost>()) {
                      locator<ArkForegroundHost>().invalidate();
                    }
                    context.read<WalletBloc>().add(const WalletStarted());
                    final _ = await locator<Exchange>().resolveAccess();
                  },
                ),
              ],
              child: Settings.appearance(
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

                  return AppliedNetworkBuilder(
                    selected: Settings.networkOf(context),
                    builder: (context, appliedNetwork) =>
                        MultiRepositoryProvider(
                          providers: [
                            RepositoryProvider<MempoolLinks>.value(
                              value: locator<Mempool>().links,
                            ),
                            RepositoryProvider<Consolidation>(
                              create: (_) =>
                                  Consolidation.open(locator<Spend>()),
                            ),
                          ],
                          child: MaterialApp.router(
                            title: 'BullBitcoin Wallet',
                            debugShowCheckedModeBanner:
                                kDebugMode &&
                                appliedNetwork != NetworkEnv.testnet &&
                                appliedNetwork != NetworkEnv.regtest,
                            routerConfig: AppRouter.router,
                            theme: AppTheme.themeData(appThemeType),
                            locale: language?.locale,
                            localizationsDelegates: [
                              StartupLocalizations.delegate,
                              SendLocalizations.delegate,
                              CoinsLocalizations.delegate,
                              NovlangReceiveLocalizationsDelegate(
                                novlangPolicy,
                              ),
                              AddressViewLocalizations.delegate,
                              NovlangLabelEditorLocalizationsDelegate(
                                novlangPolicy,
                              ),
                              NovlangAnnouncementsLocalizationsDelegate(
                                novlangPolicy,
                              ),
                              NovlangBitcoinPriceLocalizationsDelegate(
                                novlangPolicy,
                              ),
                              NovlangSettingsLocalizationsDelegate(
                                novlangPolicy,
                              ),
                              NovlangSwapLocalizationsDelegate(novlangPolicy),
                              NovlangExchangeLocalizationsDelegate(
                                novlangPolicy,
                              ),
                              NovlangOnboardingLocalizationsDelegate(
                                novlangPolicy,
                              ),
                              ...novlangLocalizationsDelegates(novlangPolicy),
                              LogsLocalizations.delegate,
                              NetworkLocalizations.delegate,
                              BtcMapFeature.localizationsDelegate,
                              BackupsFeature.localizationsDelegate,
                              NovlangQuickActionsLocalizationsDelegate(
                                novlangPolicy,
                                const QuickActionsFallbackDelegate(),
                              ),
                              Bip85Localizations.delegate,
                              NovlangAllSeedViewLocalizationsDelegate(
                                novlangPolicy,
                              ),
                              bullUiLocalizationsDelegate,
                              backupMetadataLocalizationsDelegate,
                              ...RecoverBullFeature.localizationsDelegates,
                            ],
                            supportedLocales: AppLocalizations.supportedLocales,
                            builder: (context, child) {
                              if (child == null) return const SizedBox.shrink();
                              // keyboard_actions still uses SDK Material widgets;
                              // the official bridge supports this transition.
                              final app = AccessPrivacyVeil(
                                // ignore: deprecated_member_use
                                child: MaterialUiCompatibilityBridge(
                                  child: Settings.amountScope(
                                    navigatorKey: AppRouter.rootNavigatorKey,
                                    child: BullSupportScope(
                                      onContactSupport: Support.contactSupport,
                                      child: locator<StartupFeature>().gate(
                                        logs: () => locator<LogsFacade>(),
                                        splash: locator<OnboardingFeature>()
                                            .buildLoadingSplash(context),
                                        openOnboarding: () =>
                                            OnboardingNavigation.go(
                                              AppRouter.router,
                                            ),
                                        onUnlocked: () =>
                                            AppLocator.startWalletsAfterUnlock(
                                              locator,
                                            ),
                                        app: locator<RecoverBullFeature>()
                                            .withAlerts(
                                              child,
                                              onOpen: () =>
                                                  AppRouter.router.pushNamed(
                                                    'recoverbullFlows',
                                                  ),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              return networkBanner(
                                context: context,
                                network: appliedNetwork,
                                beta: appFlavor == 'beta',
                                child: app,
                              );
                            },
                          ),
                        ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    return locator<BitcoinPriceFeature>().providePrices(child: app);
  }
}
