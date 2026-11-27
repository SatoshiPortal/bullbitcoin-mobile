import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:swaps/swaps.dart';

Swap _swap(SwapType type) {
  final created = DateTime.utc(2026, 1, type.index + 1);
  return switch (type) {
    SwapType.lightningToBitcoin || SwapType.lightningToLiquid => Swap.lnReceive(
      id: type.name,
      keyIndex: 0,
      type: type,
      status: SwapStatus.paid,
      environment: SwapEnvironment.regtest,
      creationTime: created,
      receiveWalletId: 'receive-wallet',
      invoice: '',
    ),
    SwapType.liquidToLightning || SwapType.bitcoinToLightning => Swap.lnSend(
      id: type.name,
      keyIndex: 0,
      type: type,
      status: SwapStatus.paid,
      environment: SwapEnvironment.regtest,
      creationTime: created,
      sendWalletId: 'send-wallet',
      invoice: '',
      paymentAddress: 'lockup',
      paymentAmount: 1000,
    ),
    SwapType.liquidToBitcoin || SwapType.bitcoinToLiquid => Swap.chain(
      id: type.name,
      keyIndex: 0,
      type: type,
      status: SwapStatus.paid,
      environment: SwapEnvironment.regtest,
      creationTime: created,
      sendWalletId: 'send-wallet',
      paymentAddress: 'lockup',
      paymentAmount: 1000,
    ),
  };
}

const _notice = ValueKey('ongoing-swap-notice');

Future<void> _pump(
  WidgetTester tester,
  List<Swap> swaps, {
  Locale locale = const Locale('en'),
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    locale: locale,
    supportedLocales: const [
      Locale('en'),
      Locale('es'),
      Locale('fr', 'CA'),
      Locale('de'),
    ],
    localizationsDelegates: bullUiLocalizationsDelegates,
    home: Scaffold(
      body: Column(
        children: [HomeOngoingSwaps(key: _notice, swaps: swaps)],
      ),
    ),
  ),
);

void main() {
  testWidgets('an empty list takes no vertical space', (tester) async {
    await _pump(tester, []);
    expect(tester.getSize(find.byKey(_notice)).height, 0);
    expect(find.byType(BullCarousel), findsNothing);
  });

  testWidgets('the carousel keeps list order, keys, directions and icons', (
    tester,
  ) async {
    // Deliberately oldest first, opposite to Wallet's newest-first policy.
    final swaps = SwapType.values.map(_swap).toList();
    await _pump(tester, swaps, locale: const Locale('fr', 'CA'));

    final carousel = tester.widget<BullCarousel>(find.byType(BullCarousel));
    final cards = carousel.children.cast<BullHomeNotice>();
    expect(cards.map((card) => card.key), [
      for (final swap in swaps) ValueKey(swap.id),
    ]);
    expect(cards.map((card) => card.status), everyElement('Échange en cours'));
    expect(cards.map((card) => card.detail), [
      'Lightning → BTC',
      'Lightning → L-BTC',
      'L-BTC → Lightning',
      'BTC → Lightning',
      'L-BTC → BTC',
      'BTC → L-BTC',
    ]);
    expect(cards.map((card) => card.icon), [
      Icons.arrow_downward,
      Icons.arrow_downward,
      Icons.arrow_upward,
      Icons.arrow_upward,
      Icons.swap_vert_rounded,
      Icons.swap_vert_rounded,
    ]);
    expect(
      cards.map((card) => (card.headline as BullAmount).interactive),
      everyElement(isFalse),
    );
    expect(
      (cards.last.headline as BullAmount).magnitude.value,
      BigInt.from(1000),
    );
  });

  for (final (locale, status) in [
    (const Locale('en'), 'Swap in progress'),
    (const Locale('es'), 'Intercambio en curso'),
    (const Locale('de'), 'Swap in progress'),
  ]) {
    testWidgets('home notice copy in ${locale.languageCode}', (tester) async {
      await _pump(tester, [_swap(SwapType.bitcoinToLiquid)], locale: locale);
      expect(find.text(status), findsOneWidget);
      expect(find.text('BTC → L-BTC'), findsOneWidget);
    });
  }
}
