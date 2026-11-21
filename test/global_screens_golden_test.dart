import 'package:bb_mobile/features/settings/public/settings_facade.dart';

import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/app_settings_screen.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_detail_screen.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, ScriptType;

class _Wallet extends Mock implements WalletBloc {}

class _Settings extends Mock implements SettingsCubit {}

class _Price extends Mock implements BitcoinPriceBloc {}

class _Chart extends Mock implements PriceChartCubit {}

class _Announcements extends Mock implements AnnouncementsCubit {}

class _Transactions extends Mock implements TransactionsCubit {}

class _MemoryActions implements QuickActionsStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });
  for (final type in AppThemeType.values) {
    for (final scene in ['home', 'settings', 'wallet', 'shared-sheet']) {
      testWidgets('untouched $scene ${type.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final wallet = Wallet(
          origin: 'public-preview',
          label: 'Savings',
          network: Network.bitcoinMainnet,
          isDefault: true,
          xpubFingerprint: '00000000',
          scriptType: ScriptType.bip84,
          xpub: '',
          externalPublicDescriptor: '',
          internalPublicDescriptor: '',
          signer: SignerEntity.local,
          signerDevice: null,
          balanceSat: BigInt.from(1000000),
        );
        final wallets = _Wallet();
        when(() => wallets.state).thenReturn(
          WalletState(
            status: WalletStatus.success,
            wallets: [wallet],
            backupNeeded: false,
          ),
        );
        when(() => wallets.stream).thenAnswer((_) => const Stream.empty());
        final settings = _Settings();
        when(() => settings.state).thenReturn(
          const SettingsState(
            storedSettings: SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
              hideAmounts: false,
              isSuperuser: true,
              isDevModeEnabled: true,
            ),
          ),
        );
        when(() => settings.stream).thenAnswer((_) => const Stream.empty());
        final price = _Price();
        when(() => price.state).thenReturn(
          const BitcoinPriceState(
            currency: 'CAD',
            bitcoinPrice: 125000,
            availableCurrencies: ['CAD', 'USD'],
          ),
        );
        when(() => price.stream).thenAnswer((_) => const Stream.empty());
        final chart = _Chart();
        when(() => chart.state).thenReturn(const PriceChartState());
        when(() => chart.stream).thenAnswer((_) => const Stream.empty());
        final announcements = _Announcements();
        when(() => announcements.state).thenReturn(const AnnouncementsState());
        when(() => announcements.stream)
            .thenAnswer((_) => const Stream.empty());
        final transactions = _Transactions();
        when(() => transactions.state)
            .thenReturn(const TransactionsState(transactions: []));
        when(() => transactions.stream).thenAnswer((_) => const Stream.empty());
        when(() => transactions.loadTxs()).thenAnswer((_) async {});
        when(() => transactions.close()).thenAnswer((_) async {});
        if (scene == 'wallet') {
          expect(locator.isRegistered<TransactionsCubit>(), isFalse);
          locator.registerFactoryParam<TransactionsCubit, String, void>(
            (_, _) => transactions,
          );
          addTearDown(() => locator.unregister<TransactionsCubit>());
        }
        final actions = createQuickActionsCubit(
          storage: _MemoryActions(),
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        );
        addTearDown(actions.close);
        await actions.load();
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/wallet',
          routes: [
            GoRoute(
              path: '/wallet',
              builder: (context, _) {
                Device.init(context);
                return switch (scene) {
                  'home' => Scaffold(
                    extendBodyBehindAppBar: true,
                    appBar: WalletHomeAppBar(onSettings: () {}),
                    body: WalletHomeScreen(
                      arkHost: null,
                      createSetupCubit: () => throw StateError(
                        'Populated preview does not create wallets',
                      ),
                      onEmptyMainnet: () {},
                      onImportNetworkWallet: () {},
                      onRecoverEncryptedVault: () {},
                      quickActions: actions,
                      onQuickAction: (_, _) {},
                      onCustomizeQuickActions: (_) {},
                    ),
                  ),
                  'settings' => const AppSettingsScreen(),
                  'wallet' => WalletDetailScreen(
                    walletId: wallet.id,
                    onOpenCoins: (_, _) async {},
                  ),
                  _ => Scaffold(
                    appBar: AppBar(title: const Text('Shared bottom sheet')),
                    body: Builder(
                      builder: (context) => Center(
                        child: BullButton.secondary(
                          label: 'Open shared sheet',
                          onPressed: () => BullBottomSheet.show<void>(
                            context: context,
                            child: const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Modal using the shared theme defaults.',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                };
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('untouched-preview'),
            child: MultiBlocProvider(
              providers: [
                BlocProvider<WalletBloc>.value(value: wallets),
                BlocProvider<SettingsCubit>.value(value: settings),
                BlocProvider<BitcoinPriceBloc>.value(value: price),
                BlocProvider<PriceChartCubit>.value(value: chart),
                BlocProvider<AnnouncementsCubit>.value(value: announcements),
              ],
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.themeData(type),
                routerConfig: router,
                builder: (context, child) => SettingsFacade.amountScope(
                  navigatorKey: navigatorKey,
                  child: child ?? const SizedBox.shrink(),
                ),
                localizationsDelegates: const [
                  QuickActionsLocalizations.delegate,
                  ...bullUiLocalizationsDelegates,
                  ...appLocalizationsDelegates,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          ),
        );
        await tester.pump();
        final images = <ImageProvider<Object>>{
          ...tester
              .widgetList<Image>(find.byType(Image))
              .map((widget) => widget.image),
          ...tester
              .widgetList<DecoratedBox>(find.byType(DecoratedBox))
              .map((widget) => widget.decoration)
              .whereType<BoxDecoration>()
              .map((decoration) => decoration.image?.image)
              .whereType<ImageProvider<Object>>(),
        };
        final context = tester.element(find.byType(Scaffold).first);
        await tester.runAsync(() async {
          await Future.wait(
            images.map((image) => precacheImage(image, context)),
          );
        });
        await tester.pumpAndSettle();
        if (scene == 'shared-sheet') {
          await tester.tap(find.text('Open shared sheet'));
          await tester.pumpAndSettle();
        }
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('untouched-preview')),
          matchesGoldenFile('goldens/global-screens/$scene-${type.name}.png'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
