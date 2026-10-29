import 'package:bb_mobile/features/wallet_sync/domain/usecases/watch_wallet_sync_status_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/get_wallet_sync_network_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/load_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/save_wallet_sync_settings_usecase.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_card.dart';
import 'package:bb_mobile/features/wallet_sync/public/wallet_sync_facade.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_status.dart';
import 'package:bb_mobile/features/wallet_sync/ui/widgets/wallet_recovery_panel.dart';
import 'package:bb_mobile/locator.dart';
import '../../../broadcast_signed_tx/wallet_fixture.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBloc extends Mock implements WalletBloc {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBitcoinPriceBloc extends Mock implements BitcoinPriceBloc {}

SettingsState _settingsState({
  required bool isSuperuser,
  bool isDevModeEnabled = true,
}) => SettingsState(
  storedSettings: SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
  ),
);

Widget _buildCards({
  bool dark = false,
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  required _MockBitcoinPriceBloc bitcoinPriceBloc,
}) {
  return MaterialApp(
    theme: AppTheme.themeData(dark ? AppThemeType.dark : AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<WalletBloc>.value(value: walletBloc),
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
        BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
      ],
      child: const Scaffold(body: WalletCards()),
    ),
  );
}

Widget _buildCardsRouter({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  required _MockBitcoinPriceBloc bitcoinPriceBloc,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider<WalletBloc>.value(value: walletBloc),
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
            BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
          ],
          child: const Scaffold(body: WalletCards()),
        ),
      ),
      GoRoute(
        name: SpRoute.spWalletDetail.name,
        path: SpRoute.spWalletDetail.path,
        builder: (context, state) => const Scaffold(body: Text('SP Detail')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void _stubBlocs({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  required _MockBitcoinPriceBloc bitcoinPriceBloc,
  required WalletState walletState,
  required SettingsState settingsState,
}) {
  when(() => walletBloc.state).thenReturn(walletState);
  when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => settingsCubit.state).thenReturn(settingsState);
  when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => bitcoinPriceBloc.state).thenReturn(const BitcoinPriceState());
  when(() => bitcoinPriceBloc.stream).thenAnswer((_) => const Stream.empty());
}

void main() {
  late _MockWalletBloc walletBloc;
  late _MockSettingsCubit settingsCubit;
  late _MockBitcoinPriceBloc bitcoinPriceBloc;

  setUp(() {
    walletBloc = _MockWalletBloc();
    settingsCubit = _MockSettingsCubit();
    bitcoinPriceBloc = _MockBitcoinPriceBloc();
  });

  testWidgets(
    'the wallet badge is part of the tappable card during private recovery',
    (tester) async {
      await locator.reset();
      addTearDown(locator.reset);
      locator.registerSingleton<WalletSyncFacade>(_PrivateSyncFacade());
      final wallet = publicBroadcastWallet();
      _stubBlocs(
        walletBloc: walletBloc,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
        walletState: WalletState(wallets: [wallet]),
        settingsState: _settingsState(isSuperuser: false),
      );
      await tester.pumpWidget(
        _buildCards(
          walletBloc: walletBloc,
          settingsCubit: settingsCubit,
          bitcoinPriceBloc: bitcoinPriceBloc,
        ),
      );
      final badge = find.text('Incomplete — still checking older blocks');
      expect(badge, findsOneWidget);
      expect(
        find.ancestor(of: badge, matching: find.byType(WalletCard)),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'private recovery has one contrasting determinate card indicator (dark=$dark)',
      (tester) async {
        await locator.reset();
        addTearDown(locator.reset);
        final wallet = publicBroadcastWallet();
        locator.registerSingleton<WalletSyncFacade>(
          WalletSyncFacade(
            network: _Network(),
            load: _Load(),
            save: _Save(),
            start: _Start(),
            watch: _Watch(
              Stream.value(
                WalletSyncStatus(
                  progress: BitcoinSyncProgress(
                    key: WalletNetworkKey(wallet.id, 'bitcoin', 'mainnet'),
                    phase: BitcoinSyncPhase.checkingBlocks,
                    isRecovery: true,
                    fraction: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
        _stubBlocs(
          walletBloc: walletBloc,
          settingsCubit: settingsCubit,
          bitcoinPriceBloc: bitcoinPriceBloc,
          walletState: WalletState(
            wallets: [wallet],
            syncStatus: {wallet.id: true},
          ),
          settingsState: _settingsState(isSuperuser: false),
        );
        await tester.pumpWidget(
          _buildCards(
            walletBloc: walletBloc,
            settingsCubit: settingsCubit,
            bitcoinPriceBloc: bitcoinPriceBloc,
            dark: dark,
          ),
        );
        await tester.pump();
        expect(
          find.byType(LinearProgressIndicator),
          findsNothing,
          reason:
              'the card must not overlay its legacy loading bar on CBF recovery',
        );
        final ringFinder = find.byType(CircularProgressIndicator);
        expect(ringFinder, findsOneWidget);
        final ring = tester.widget<CircularProgressIndicator>(ringFinder);
        expect(ring.value, 0.5);
        final color = ring.color;
        expect(color, isNotNull);
        final cardBackground = Theme.of(
          tester.element(ringFinder),
        ).colorScheme.surface;
        if (color != null) {
          final a = color.computeLuminance(),
              b = cardBackground.computeLuminance();
          final contrast = a > b
              ? (a + 0.05) / (b + 0.05)
              : (b + 0.05) / (a + 0.05);
          expect(contrast, greaterThanOrEqualTo(4.5));
        }
        final card = tester.getRect(find.byType(WalletCard));
        final ringRect = tester.getRect(ringFinder);
        expect(card.contains(ringRect.topLeft), isTrue);
        expect(card.contains(ringRect.bottomRight), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  Future<void> pumpCards(
    WidgetTester tester, {
    required bool isSpWalletSetup,
    required bool isSpFeatureEnabled,
    required bool isSuperuser,
    required bool isDevModeEnabled,
  }) async {
    _stubBlocs(
      walletBloc: walletBloc,
      settingsCubit: settingsCubit,
      bitcoinPriceBloc: bitcoinPriceBloc,
      walletState: WalletState(
        isSpWalletSetup: isSpWalletSetup,
        isSpFeatureEnabled: isSpFeatureEnabled,
      ),
      settingsState: _settingsState(
        isSuperuser: isSuperuser,
        isDevModeEnabled: isDevModeEnabled,
      ),
    );
    await tester.pumpWidget(
      _buildCards(
        walletBloc: walletBloc,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
      ),
    );
    await tester.pump();
  }

  group('SP wallet card visibility', () {
    testWidgets(
      'renders the SP card when enabled, superuser, dev mode, setup',
      (tester) async {
        await pumpCards(
          tester,
          isSpWalletSetup: true,
          isSpFeatureEnabled: true,
          isSuperuser: true,
          isDevModeEnabled: true,
        );

        expect(find.text('Silent Payments'), findsOneWidget);
      },
    );

    // The card gates on `isSpFeatureEnabled && isSpWalletSetup`. The bloc
    // derives isSpFeatureEnabled from superuser + dev mode, so the card ignores
    // the raw settings flags here; one gate-off case covers every way the gate
    // can be false.
    testWidgets('hides the SP card when the feature gate is off', (
      tester,
    ) async {
      await pumpCards(
        tester,
        isSpWalletSetup: true,
        isSpFeatureEnabled: false,
        isSuperuser: true,
        isDevModeEnabled: true,
      );

      expect(find.text('Silent Payments'), findsNothing);
    });

    testWidgets('hides the SP card when the wallet is not set up', (
      tester,
    ) async {
      await pumpCards(
        tester,
        isSpWalletSetup: false,
        isSpFeatureEnabled: true,
        isSuperuser: true,
        isDevModeEnabled: true,
      );

      expect(find.text('Silent Payments'), findsNothing);
    });

    testWidgets('tapping the SP card opens the detail route when setup', (
      tester,
    ) async {
      _stubBlocs(
        walletBloc: walletBloc,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
        walletState: const WalletState(
          isSpWalletSetup: true,
          isSpFeatureEnabled: true,
        ),
        settingsState: _settingsState(isSuperuser: true),
      );

      await tester.pumpWidget(
        _buildCardsRouter(
          walletBloc: walletBloc,
          settingsCubit: settingsCubit,
          bitcoinPriceBloc: bitcoinPriceBloc,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Silent Payments'));
      await tester.pumpAndSettle();

      expect(find.text('SP Detail'), findsOneWidget);
    });
  });
}

class _PrivateSyncFacade extends Fake implements WalletSyncFacade {
  @override
  Widget cardSyncForWallet(String walletId, {required bool isSyncing}) =>
      const WalletIncompleteBalance(status: WalletSyncStatus());
}

class _Network extends Fake implements GetWalletSyncNetworkUsecase {}

class _Load extends Fake implements LoadWalletSyncSettingsUsecase {}

class _Save extends Fake implements SaveWalletSyncSettingsUsecase {}

class _Start extends Fake implements StartWalletSyncUsecase {}

class _Watch extends Fake implements WatchWalletSyncStatusUsecase {
  final Stream<WalletSyncStatus> stream;
  _Watch(this.stream);
  @override
  Stream<WalletSyncStatus> execute(String walletId) => stream;
}
