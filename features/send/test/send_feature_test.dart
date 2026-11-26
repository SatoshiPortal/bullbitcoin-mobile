import 'package:bull_ui/app_theme.dart';
import 'package:electrum/electrum.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:send/setup.dart';
import 'package:spend/testing.dart';

class _Electrum extends Mock implements Electrum {}

class _Transactions extends Mock implements ElectrumTransactions {}

class _Fees extends Mock implements Fees {}

class _Environment extends Mock implements ActiveEnvironmentReader {}

void main() {
  testWidgets('mount keeps the signed transaction and fee routes', (
    tester,
  ) async {
    final electrum = _Electrum();
    when(() => electrum.transactions).thenReturn(_Transactions());
    final environment = _Environment();
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.mainnet));
    final routes = SendFeature.mount(
      spend: FakeSpend(),
      fees: _Fees(),
      electrum: electrum,
      environment: environment,
      goToWalletHome: (_) {},
      broadcastSuccessImage: const AssetImage('unused-in-this-test'),
      missingWalletRedirect: '/wallet',
      selectBalanceSat: (_, _) => 0,
      payment: () => throw StateError('payment not opened'),
      openCoins: (_, _) {},
      orderUnderReview: (_) => const SizedBox.shrink(),
      paymentArrowImage: const AssetImage('unused-arrow'),
      pollSettlement: (_, {required isActive}) async {},
    );
    final router = GoRouter(
      initialLocation: '/broadcast-signed-tx',
      routes: [
        routes.payment,
        routes.broadcastSignedTx,
        routes.consolidation,
        routes.replaceByFee,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: SendLocalizations.localizationsDelegates,
        supportedLocales: SendLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Broadcast signed transaction'), findsOneWidget);
    expect(
      router.namedLocation('broadcastScanQr'),
      '/broadcast-signed-tx/scan-qr',
    );
    expect(
      router.namedLocation('broadcastScanNfc'),
      '/broadcast-signed-tx/scan-nfc',
    );
    expect(
      router.namedLocation(
        'consolidation',
        pathParameters: {'walletId': 'example'},
      ),
      '/consolidate/example',
    );
    expect(router.namedLocation('replaceByFeeFlow'), '/replace-by-fee-flow');
    expect(router.namedLocation('send'), '/send');
  });
}
