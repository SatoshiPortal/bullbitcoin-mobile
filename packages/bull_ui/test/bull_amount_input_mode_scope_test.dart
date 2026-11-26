import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets('input mode writes and Undo persist without resetting the unit', (
    tester,
  ) async {
    var fiat = false;
    final writes = <bool>[];
    late StateSetter publish;
    await tester.pumpWidget(
      wrapWithTheme(
        StatefulBuilder(
          builder: (context, update) {
            publish = update;
            return BullAmountScope(
              snapshot: BullAmountSnapshot(
                unit: BitcoinUnit.sats,
                hideAmounts: false,
                isReady: true,
                startInFiat: fiat,
              ),
              writeUnit: (_) async => false,
              writeInputMode: (target) async {
                writes.add(target);
                update(() => fiat = target);
                return true;
              },
              child: Builder(
                builder: (context) {
                  final scope = BullAmountScope.maybeOf(context);
                  return TextButton(
                    onPressed: scope == null
                        ? null
                        : () => unawaited(
                            scope.changeDefaultInputMode(
                              true,
                              bitcoinMessage: 'Bitcoin default',
                              fiatMessage: 'Fiat default',
                              failureMessage: 'Preference failed',
                            ),
                          ),
                    child: const Text('Set fiat'),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Set fiat'));
    await tester.pumpAndSettle();
    expect(fiat, isTrue);
    expect(find.text('Fiat default'), findsOneWidget);
    final scope = tester.widget<BullAmountScope>(find.byType(BullAmountScope));
    expect(scope.snapshot.unit, BitcoinUnit.sats);
    expect(scope.snapshot.startInFiat, isTrue);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fiat, isFalse);
    expect(writes, [true, false]);
    expect(
      tester
          .widget<BullAmountScope>(find.byType(BullAmountScope))
          .snapshot
          .unit,
      BitcoinUnit.sats,
    );
    await tester.tap(find.text('Set fiat'));
    await tester.pumpAndSettle();
    publish(() => fiat = false);
    await tester.pump();
    publish(() => fiat = true);
    await tester.pump();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fiat, isTrue);
    expect(writes, [true, false, true]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
