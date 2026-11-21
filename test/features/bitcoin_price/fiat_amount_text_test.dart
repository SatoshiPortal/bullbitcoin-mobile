import 'dart:async';

import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/public/fiat_amount_text.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _PriceBloc extends Mock implements BitcoinPriceBloc {}

Widget host(Widget child, {bool hide = false}) => wrapWithTheme(
  BullAmountScope(
    snapshot: BullAmountSnapshot(
      unit: BitcoinUnit.sats,
      hideAmounts: hide,
      isReady: true,
    ),
    writeUnit: (_) async => true,
    child: child,
  ),
);

void main() {
  testWidgets('Bitcoin rendering uses the scope and keeps signed magnitudes', (
    tester,
  ) async {
    await tester.pumpWidget(host(BullAmount.signedSats(-12345)));
    expect(find.text('-12,345 sats'), findsOneWidget);
    await tester.tap(find.text('-12,345 sats'));
    await tester.pump();
    expect(find.text('-0.00012345 BTC'), findsOneWidget);
  });

  testWidgets('explicit fiat remains a separate noninteractive amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const FiatAmountText(formattedAmount: '12.34 USD', hideAmounts: false),
      ),
    );
    expect(find.text('12.34 USD'), findsOneWidget);
    expect(find.byType(BullAmountUnitToggle), findsNothing);
  });

  testWidgets('privacy and its existing explicit exception are preserved', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            BullAmount.signedSats(12345, interactive: false),
            BullAmount.signedSats(
              12345,
              interactive: false,
              overrideHideAmounts: true,
            ),
            const FiatAmountText(
              formattedAmount: '12.34 USD',
              hideAmounts: true,
            ),
          ],
        ),
        hide: true,
      ),
    );
    expect(find.text('** sats'), findsOneWidget);
    expect(find.text('12,345 sats'), findsOneWidget);
    expect(find.text('** USD'), findsOneWidget);
  });

  testWidgets('live fiat waits for a quote and masks the quoted amount', (
    tester,
  ) async {
    final bloc = _PriceBloc();
    final quotes = StreamController<BitcoinPriceState>();
    addTearDown(quotes.close);
    when(() => bloc.stream).thenAnswer((_) => quotes.stream);
    when(() => bloc.state).thenReturn(const BitcoinPriceState());

    await tester.pumpWidget(
      host(
        BlocProvider<BitcoinPriceBloc>.value(
          value: bloc,
          child: const Column(
            children: [
              FiatAmountText.quote(12500, hideAmounts: false),
              FiatAmountText.quote(12500, hideAmounts: true),
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('CAD'), findsNothing);

    const priced = BitcoinPriceState(currency: 'CAD', bitcoinPrice: 100000);
    when(() => bloc.state).thenReturn(priced);
    quotes.add(priced);
    await tester.pump();

    expect(find.text('12.50 CAD'), findsOneWidget);
    expect(find.text('** CAD'), findsOneWidget);
  });
}
