import 'package:bb_mobile/cbf_foreground_service.dart';
import 'package:bb_mobile/cbf_foreground_sync.dart';
import 'package:bb_mobile/cbf_background_persistence.dart';
import 'package:notifications/notifications.dart';
import 'package:bull_tor/tor.dart' as tor_api;
import 'package:bb_mobile/core/background_tasks/cbf_sync_network_policy.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/cbf_lifecycle.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_failure_listener.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_logs/bull_logs.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_tor/tor_adapter.dart' as tor;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_bloc/flutter_bloc.dart';

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
  CbfLifecycle? _cbfLifecycle;
  late final tor.TorLifecycleController _torLifecycleController;
  // final router = AppRouter.router;

  @override
  void initState() {
    super.initState();

    _torLifecycleController = locator<tor.TorLifecycleController>()..start();
    if (locator.isRegistered<BitcoinSyncRouting>()) {
      final foreground = defaultTargetPlatform == TargetPlatform.android
          ? CbfForegroundSync(
              service: AndroidCbfForegroundService(
                permissions: NotificationPermissionsFacade(
                  gateway: FlutterNotificationPermissionGateway(
                    channelId: 'cbf_sync',
                  ),
                ),
              ),
              labels: () async {
                final settings = await locator<SettingsRepository>().fetch();
                final language = settings.language ?? Language.fromKeyboard();
                final localized = await AppLocalizations.delegate.load(
                  language.locale,
                );
                return (
                  title: localized.syncServiceTitle,
                  body: localized.syncServiceBody,
                  progressBody: localized.syncServiceProgressBody,
                );
              },
              onProtectionChanged: () => _cbfLifecycle?.protectionChanged(),
            )
          : null;
      _cbfLifecycle = CbfLifecycle(
        routing: locator<BitcoinSyncRouting>(),
        metadata: locator<WalletMetadataDatasource>(),
        networkPolicy: locator<CbfSyncNetworkPolicy>(),
        foregroundSync: foreground,
        backgroundPersistence: defaultTargetPlatform == TargetPlatform.iOS
            ? CbfBackgroundPersistence()
            : null,
        onBackgroundProtectionChanged:
            _torLifecycleController.setBackgroundActive,
        proxyChanges: locator<tor_api.Tor>().embedded.states
            .map((state) => state.isReady)
            .distinct()
            .map((_) {}),
        transportChanges: locator<SettingsRepository>().torPolicyChanges,
      )..start(WidgetsBinding.instance.lifecycleState);
    }
    // Initialize the AppLifecycleListener class and pass callbacks
    _listener = AppLifecycleListener(onStateChange: _onStateChanged);
  }

  @override
  void dispose() {
    // Do not forget to dispose the listener
    _listener.dispose();
    unawaited(_cbfLifecycle?.dispose());
    if (locator.isRegistered<PayjoinLifecycle>()) {
      unawaited(locator<PayjoinLifecycle>().dispose());
    }
    _torLifecycleController.dispose();

    super.dispose();
  }

  // Wallet/swap sync on resume is handled by SyncCoordinator's own
  // AppLifecycleListener — see lib/core/sync/sync_coordinator.dart.
  void _onStateChanged(AppLifecycleState state) {
    log.info(state.name);
    _cbfLifecycle?.onStateChange(state);
    if (locator.isRegistered<PayjoinLifecycle>()) {
      resumePayjoinsOnAppResume(state, locator<PayjoinLifecycle>());
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

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => locator<SettingsCubit>()..init()),
        BlocProvider(
          create: (_) =>
              locator<AppStartupBloc>()..add(const AppStartupStarted()),
        ),
        BlocProvider(
          create: (_) =>
              locator<BitcoinPriceBloc>()..add(const BitcoinPriceStarted()),
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
              listener: (context, settings) {
                // If wallets exist and the app has started successfully,
                // we can start the wallet bloc to fetch the wallets.
                context.read<WalletBloc>().add(const WalletStarted());
                // Also fetch user summary to check if user is logged in
                // and connect WebSocket if so (handled by ExchangeListener)
                ExchangeScope.refreshSession(context);
                // Reconnect WebSocket here too — when AppStartupBloc retries
                // after a pre-warm KeychainLockedException, the SettingsCubit
                // env-change listener below has ALREADY fired during pre-warm
                // (with the keychain locked) and won't fire again, so without
                // this call the WebSocket stays disconnected post-unlock until
                // the user toggles environment or cold-launches.
                ExchangeScope.reconnectNotifications(context);
              },
            ),
            BlocListener<SettingsCubit, SettingsState>(
              listenWhen: (previous, current) =>
                  previous.environment != null &&
                  previous.environment != current.environment,
              listener: (context, settings) async {
                // Re-fetch user summary (re-init exchange bloc) and wallets
                //  when environment changes
                context.read<WalletBloc>().add(const WalletStarted());
                await ExchangeScope.refreshSession(context);
                // Reconnect WebSocket for the new environment
                await ExchangeScope.reconnectNotifications(context);
              },
            ),
          ],
          child:
              BlocSelector<
                SettingsCubit,
                SettingsState,
                (Language?, AppThemeMode?)
              >(
                selector: (settings) =>
                    (settings.language, settings.storedSettings?.themeMode),
                builder: (context, data) {
                  final (language, themeMode) = data;
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

                  return MaterialApp.router(
                    title: 'BullBitcoin Wallet',
                    debugShowCheckedModeBanner: kDebugMode,
                    routerConfig: AppRouter.router,
                    theme: AppTheme.themeData(appThemeType),
                    locale: language?.locale,
                    localizationsDelegates: [
                      ...AppLocalizations.localizationsDelegates,
                      LogsLocalizations.delegate,
                    ],
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) {
                      final app = AppStartupWidget(app: child!);
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
                  );
                },
              ),
        ),
      ),
    );
  }
}
