import 'package:preferences/preferences.dart' show Environment, SettingsEntity;
import 'package:settings/settings.dart';

import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:settings/testing.dart';
import 'package:transactions/testing.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart'
    show QuickActionsLocalizations;
import 'package:overview/overview.dart' show OverviewWalletDetail;
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

// Screen fixtures use public owner widgets rather than the retired aggregate bloc.
class _Settings extends Mock implements SettingsCubit {}

class _Transactions extends Mock implements TransactionsCubit {}

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
    for (final scene in ['settings', 'wallet', 'shared-sheet']) {
      testWidgets('untouched $scene ${type.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const amountDisplay = (
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          hideAmounts: false,
        );
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

        final transactions = _Transactions();
        when(() => transactions.state)
            .thenReturn(const TransactionsState(transactions: []));
        when(() => transactions.stream).thenAnswer((_) => const Stream.empty());
        when(() => transactions.loadTxs()).thenAnswer((_) async {});
        when(() => transactions.close()).thenAnswer((_) async {});
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
                  'settings' => const AppSettingsScreen(),
                  'wallet' => OverviewWalletDetail(
                    walletId: 'public-preview',
                    walletName: 'Savings',
                    settings: const SizedBox.shrink(),
                    isLoading: false,
                    unavailableMessage: context.loc.walletLoadFailed,
                    hasBalance: true,
                    isLiquid: false,
                    scopeWalletHistory: (_, child) =>
                        BlocProvider<TransactionsCubit>.value(
                          value: transactions,
                          child: child,
                        ),
                    refreshPrice: (_) async {},
                    refreshWalletHistory: (_) async {},
                    balanceCard: (_) => const SizedBox.shrink(),
                    consolidation: (_) => const SizedBox.shrink(),
                    coinsEntry: (_) => const SizedBox.shrink(),
                    liquidDisclosure: (_) => const SizedBox.shrink(),
                    history: (_) => const SliverToBoxAdapter(),
                    bottomActions: const SizedBox.shrink(),
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
          MultiBlocProvider(
            providers: [
              BlocProvider<SettingsCubit>.value(value: settings),
              BitcoinPriceFixture.prices(
                amountDisplay: amountDisplay,
                currency: 'CAD',
                bitcoinPrice: 125000,
                availableCurrencies: const ['CAD', 'USD'],
              ),
              BitcoinPriceFixture.chart(),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.themeData(type),
              routerConfig: router,
              builder: (context, child) => Settings.amountScope(
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
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
