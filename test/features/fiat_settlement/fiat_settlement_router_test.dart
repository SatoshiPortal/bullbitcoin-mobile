import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/has_bull_bitcoin_account_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/ui/fiat_settlement_router.dart';
import 'package:bb_mobile/features/fiat_settlement/ui/screens/fiat_settlement_editor_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockFacade extends Mock implements FiatSettlementFacade {}

class _MockHasAccount extends Mock implements HasBullBitcoinAccountUsecase {}

class _FakeGetSettings implements GetSettingsUsecase {
  _FakeGetSettings(this.environment);
  final Environment environment;

  @override
  Future<SettingsEntity> execute() async => SettingsEntity(
    environment: environment,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/wallet',
  routes: [
    GoRoute(
      path: '/wallet',
      builder: (_, _) => const Scaffold(body: Text('WALLET-HOME')),
    ),
    FiatSettlementRouter.route,
  ],
);

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    if (locator.isRegistered<GetSettingsUsecase>()) locator.reset();
  });
  tearDown(() => locator.reset());

  void registerEditorDependencies() {
    final facade = _MockFacade();
    when(() => facade.configuration()).thenAnswer(
      (_) async => const Ok(
        FiatSettlementConfigurationView(products: [], credentialActive: false),
      ),
    );
    final hasAccount = _MockHasAccount();
    when(() => hasAccount.execute()).thenAnswer((_) async => true);
    locator
      ..registerSingleton<FiatSettlementFacade>(facade)
      ..registerSingleton<HasBullBitcoinAccountUsecase>(hasAccount);
  }

  testWidgets('opens the editor for each valid product on mainnet', (
    tester,
  ) async {
    for (final wire in [
      'lightning_address',
      'payment_page',
      'pos',
      'invoice',
    ]) {
      await locator.reset();
      locator.registerSingleton<GetSettingsUsecase>(
        _FakeGetSettings(Environment.mainnet),
      );
      registerEditorDependencies();
      final router = _router();
      addTearDown(router.dispose);
      await _pump(tester, router);

      router.go('/fiat-settlement/$wire');
      await tester.pumpAndSettle();

      expect(
        find.byType(FiatSettlementEditorScreen),
        findsOneWidget,
        reason: wire,
      );
      expect(find.text('Page not found'), findsNothing, reason: wire);
    }
  });

  testWidgets('an unknown product uses the invalid-route screen', (
    tester,
  ) async {
    locator.registerSingleton<GetSettingsUsecase>(
      _FakeGetSettings(Environment.mainnet),
    );
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    router.go('/fiat-settlement/not-a-product');
    await tester.pumpAndSettle();

    // The established invalid-route surface — never a silent fallback to a
    // real product editor.
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.byType(FiatSettlementEditorScreen), findsNothing);
  });

  testWidgets('a non-mainnet environment is dismissed to the wallet home', (
    tester,
  ) async {
    locator.registerSingleton<GetSettingsUsecase>(
      _FakeGetSettings(Environment.testnet),
    );
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    router.go('/fiat-settlement/invoice');
    await tester.pumpAndSettle();

    expect(find.text('WALLET-HOME'), findsOneWidget);
    expect(find.byType(FiatSettlementEditorScreen), findsNothing);
  });
}
