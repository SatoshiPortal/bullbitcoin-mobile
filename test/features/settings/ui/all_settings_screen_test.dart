import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bip85_entropy/router.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_routes.dart';
import 'package:bb_mobile/features/mempool_settings/router.dart';
import 'package:bb_mobile/features/passphrase_wallet/public/passphrase_wallet_routes.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_entry_registry.dart';
import 'package:bb_mobile/features/settings/ui/screens/all_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/help_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/tools_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:bb_mobile/features/status_check/router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockServiceStatusCubit extends Mock implements ServiceStatusCubit {}

class _MockExchangeCubit extends Mock implements ExchangeCubit {}

class _MockExchangeState extends Mock implements ExchangeState {}

void main() {
  final english = AppLocalizationsEn();

  testWidgets('the settings root offers exactly the five requested groups', (
    tester,
  ) async {
    await _pumpSettings(tester);

    expect(_tileTitles(tester), [
      english.settingsWalletAndBitcoinTitle,
      english.settingsExchangeTitle,
      english.settingsAppAndDeviceTitle,
      english.settingsToolsTitle,
      english.settingsHelpAndInfoTitle,
    ]);
  });

  testWidgets('Tools opens and reaches every tool', (tester) async {
    await _pumpSettings(tester, isSuperuser: true, isDevModeEnabled: true);

    await tester.tap(find.text(english.settingsToolsTitle));
    await tester.pumpAndSettle();

    expect(_tileTitles(tester), [
      english.bitcoinSettingsBroadcastTransactionTitle,
      english.settingsNostrKeysTitle,
      english.settingsBtcMapTitle,
      english.bitcoinSettingsBip85EntropiesTitle,
    ]);

    for (final title in [
      english.bitcoinSettingsBroadcastTransactionTitle,
      english.settingsNostrKeysTitle,
      english.settingsBtcMapTitle,
      english.bitcoinSettingsBip85EntropiesTitle,
    ]) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text('destination: $title'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Help and info opens and reaches service status and logs', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.tap(find.text(english.settingsHelpAndInfoTitle));
    await tester.pumpAndSettle();

    expect(_tileTitles(tester), [
      english.settingsGetHelpLabel,
      english.settingsGithubLabel,
      english.settingsTermsOfServiceTitle,
      english.settingsServiceStatusTitle,
      english.logSettingsLogsTitle,
    ]);

    for (final title in [
      english.settingsServiceStatusTitle,
      english.logSettingsLogsTitle,
    ]) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text('destination: $title'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Wallet and Bitcoin lists the requested entries and opens them', (
    tester,
  ) async {
    GetIt.I.registerLazySingleton(
      () => SettingsEntryRegistry()
        ..register(
          SettingsEntryContribution(
            id: 'bullvault',
            section: SettingsEntrySection.wallet,
            title: (localization) => localization.settingsBullVaultEntryTitle,
            icon: Icons.security,
            open: (context) => context.pushNamed('bullvault-menu'),
          ),
        ),
    );
    addTearDown(GetIt.I.reset);

    await _pumpSettings(tester, isSuperuser: true);

    await tester.tap(find.text(english.settingsWalletAndBitcoinTitle));
    await tester.pumpAndSettle();

    expect(_tileTitles(tester), [
      english.walletRecoverySettingsTitle,
      english.dataBackupSettingsTitle,
      english.walletSettingsImportWalletTitle,
      english.passphraseWalletSettingsTitle,
      english.bitcoinSettingsElectrumServerTitle,
      english.bitcoinSettingsMempoolServerTitle,
      english.bitcoinSettingsAutoTransferTitle,
      english.bitcoinSettingsPayjoinTitle,
      english.settingsBullVaultEntryTitle,
      english.allSeedViewTitle,
    ]);

    for (final title in _tileTitles(tester)) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(
        find.text('destination: $title'),
        findsOneWidget,
        reason: 'Expected "$title" to open its destination',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the Seed Viewer stays out of the menu without superuser', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.tap(find.text(english.settingsWalletAndBitcoinTitle));
    await tester.pumpAndSettle();

    expect(_tileTitles(tester), isNot(contains(english.allSeedViewTitle)));
  });

  testWidgets('support chat asks a signed-out user to sign in first', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.tap(find.text(english.settingsHelpAndInfoTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(english.settingsGetHelpLabel));
    await tester.pumpAndSettle();

    expect(find.text('destination: sign in for support'), findsOneWidget);
  });

  testWidgets('support chat opens directly for a signed-in user', (
    tester,
  ) async {
    await _pumpSettings(tester, isLoggedIn: true);

    await tester.tap(find.text(english.settingsHelpAndInfoTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(english.settingsGetHelpLabel));
    await tester.pumpAndSettle();

    expect(find.text('destination: support chat'), findsOneWidget);
  });

  testWidgets('the old backup-settings deep link still lands on the screen', (
    tester,
  ) async {
    await _pumpSettings(tester);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .context
        .go('/settings/${SettingsRoute.legacyBackupSettings.path}');
    await tester.pumpAndSettle();

    expect(
      find.text('destination: ${english.walletRecoverySettingsTitle}'),
      findsOneWidget,
    );
  });
}

List<String> _tileTitles(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => (tile.title! as Text).data!)
    .toList();

Future<void> _pumpSettings(
  WidgetTester tester, {
  bool isSuperuser = false,
  bool isDevModeEnabled = false,
  bool isLoggedIn = false,
}) async {
  final english = AppLocalizationsEn();
  final settingsCubit = _MockSettingsCubit();
  final serviceStatusCubit = _MockServiceStatusCubit();
  final exchangeCubit = _MockExchangeCubit();
  final exchangeState = _MockExchangeState();
  when(() => exchangeState.notLoggedIn).thenReturn(!isLoggedIn);
  when(() => exchangeCubit.state).thenReturn(exchangeState);
  when(
    () => exchangeCubit.stream,
  ).thenAnswer((_) => const Stream<ExchangeState>.empty());
  when(() => settingsCubit.state).thenReturn(
    SettingsState(
      storedSettings: SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
        isSuperuser: isSuperuser,
        isDevModeEnabled: isDevModeEnabled,
      ),
    ),
  );
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => serviceStatusCubit.state).thenReturn(const ServiceStatusState());
  when(
    () => serviceStatusCubit.stream,
  ).thenAnswer((_) => const Stream<ServiceStatusState>.empty());
  when(() => serviceStatusCubit.checkStatus()).thenAnswer((_) async {});

  GoRoute destination(String name, String path, String title) => GoRoute(
    name: name,
    path: path,
    builder: (context, state) =>
        Scaffold(appBar: AppBar(), body: Text('destination: $title')),
  );

  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        name: SettingsRoute.settings.name,
        builder: (context, state) => const AllSettingsScreen(),
        routes: [
          GoRoute(
            name: SettingsRoute.walletSettings.name,
            path: SettingsRoute.walletSettings.path,
            builder: (context, state) => const WalletSettingsScreen(),
          ),
          GoRoute(
            name: SettingsRoute.tools.name,
            path: SettingsRoute.tools.path,
            builder: (context, state) => const ToolsSettingsScreen(),
          ),
          GoRoute(
            name: SettingsRoute.helpAndInfo.name,
            path: SettingsRoute.helpAndInfo.path,
            builder: (context, state) => const HelpSettingsScreen(),
          ),
          GoRoute(
            path: SettingsRoute.legacyBackupSettings.path,
            redirect: (_, _) =>
                '${SettingsRoute.settings.path}/'
                '${SettingsRoute.walletRecoverySettings.path}',
          ),
          destination(
            SettingsRoute.walletRecoverySettings.name,
            SettingsRoute.walletRecoverySettings.path,
            english.walletRecoverySettingsTitle,
          ),
          destination(
            SettingsRoute.dataBackupSettings.name,
            SettingsRoute.dataBackupSettings.path,
            english.dataBackupSettingsTitle,
          ),
          destination(
            SettingsRoute.autoswapSettings.name,
            SettingsRoute.autoswapSettings.path,
            english.bitcoinSettingsAutoTransferTitle,
          ),
          destination(
            SettingsRoute.payjoinSettings.name,
            SettingsRoute.payjoinSettings.path,
            english.bitcoinSettingsPayjoinTitle,
          ),
          destination(
            SettingsRoute.allSeedView.name,
            SettingsRoute.allSeedView.path,
            english.allSeedViewTitle,
          ),
          destination(
            SettingsRoute.btcMap.name,
            SettingsRoute.btcMap.path,
            english.settingsBtcMapTitle,
          ),
        ],
      ),
      destination(
        ImportWalletRoute.importWalletHome.name,
        ImportWalletRoute.importWalletHome.path,
        english.walletSettingsImportWalletTitle,
      ),
      destination(
        PassphraseWalletRoute.wallets.name,
        '/${PassphraseWalletRoute.wallets.path}',
        english.passphraseWalletSettingsTitle,
      ),
      destination(
        ElectrumSettingsRoute.electrumSettings.name,
        '/electrum-settings',
        english.bitcoinSettingsElectrumServerTitle,
      ),
      destination(
        MempoolSettingsRoute.name,
        '/mempool-settings',
        english.bitcoinSettingsMempoolServerTitle,
      ),
      destination(
        BroadcastSignedTxRoute.broadcastHome.name,
        '/broadcast',
        english.bitcoinSettingsBroadcastTransactionTitle,
      ),
      destination(
        KeychainManifestRoutes.listName,
        '/nostr-keys',
        english.settingsNostrKeysTitle,
      ),
      destination(
        Bip85EntropyRoute.bip85Home.name,
        '/bip85',
        english.bitcoinSettingsBip85EntropiesTitle,
      ),
      destination(
        StatusCheckRoute.serviceStatus.name,
        '/service-status',
        english.settingsServiceStatusTitle,
      ),
      destination('logs', '/logs', english.logSettingsLogsTitle),
      destination(
        ExchangeRoute.exchangeLoginForSupport.name,
        ExchangeRoute.exchangeLoginForSupport.path,
        'sign in for support',
      ),
      destination(
        ExchangeSupportChatFacade.routeName,
        '/support-chat',
        'support chat',
      ),
      destination('bullvault-menu', '/bullvault', 'BullVault (miniscript)'),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<ServiceStatusCubit>.value(value: serviceStatusCubit),
          BlocProvider<ExchangeCubit>.value(value: exchangeCubit),
        ],
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
