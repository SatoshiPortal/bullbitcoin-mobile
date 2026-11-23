import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:coins/coins.dart';
import 'package:flutter/widgets.dart' show StatefulBuilder, StateSetter;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets('exposes selection and removes a newly unavailable input', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final first = (
      outpoint: (txId: 'a' * 64, vout: 0),
      amount: Sats.fromInt(2000),
      address: 'first address',
      addressType: 'Receive',
    );
    final second = (
      outpoint: (txId: 'b' * 64, vout: 0),
      amount: Sats.fromInt(3000),
      address: 'second address',
      addressType: 'Change',
    );
    var available = [first, second, first];
    late StateSetter refresh;
    await tester.pumpWidget(
      wrapWithTheme(
        StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return CoinSelectionSheet(
              bitcoinUnit: BitcoinUnit.sats,
              exchangeRate: null,
              fiatCurrency: 'CAD',
              coins: available,
              initialSelection: {first.outpoint},
              requestedAmount: Sats.fromInt(5000),
              labels: _labels,
              onDone: (_) => fail('Selection was not submitted'),
              addressBuilder: (address, style, color) =>
                  BullText(address, style: style),
            );
          },
        ),
      ),
    );

    final done = find.byType(BullButton);
    final secondTarget = find.byKey(
      ValueKey(second.outpoint),
      skipOffstage: false,
    );
    await tester.ensureVisible(secondTarget);
    await tester.pumpAndSettle();
    final secondCoin = find.bySemanticsLabel(RegExp(', second address\$'));
    expect(tester.widget<BullButton>(done).disabled, isTrue);
    expect(
      tester.getSemantics(secondCoin),
      matchesSemantics(
        isButton: true,
        hasCheckedState: true,
        hasTapAction: true,
      ),
    );
    expect(tester.getSize(secondTarget).height, greaterThanOrEqualTo(48));
    await tester.tap(secondTarget);
    await tester.pump();
    expect(tester.widget<BullButton>(done).disabled, isFalse);
    expect(
      tester.getSemantics(secondCoin),
      matchesSemantics(
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    refresh(() => available = [second]);
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp(', first address\$')), findsNothing);
    expect(tester.widget<BullButton>(done).disabled, isTrue);
    semantics.dispose();
  });
}

final CoinSelectionLabels _labels = (
  title: 'Select coins',
  close: 'Close',
  requested: (amount) => 'Requested: $amount',
  insufficient: 'Insufficient amount',
  address: 'Address',
  type: 'Type',
  done: 'Done',
);
