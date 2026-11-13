import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

const defaults = [
  QuickAction.map,
  QuickAction.transfer,
  QuickAction.history,
  QuickAction.settings,
];
const walletActions = {
  ...defaults,
  QuickAction.support,
  QuickAction.priceHistory,
};

void main() {
  test('OFF keeps More with Settings Support and Price history', () {
    final layout = QuickActionsLayout.resolve(available: walletActions);
    expect(layout.primary, defaults.take(3));
    expect(layout.more, [
      QuickAction.settings,
      QuickAction.support,
      QuickAction.priceHistory,
    ]);
  });

  test('ON prioritizes exchange then app controls then hidden favorites', () {
    final selection = QuickActionSelection([QuickAction.buy, QuickAction.map]);
    final layout = QuickActionsLayout.resolve(
      available: QuickAction.values.toSet(),

      selection: selection,
    );
    expect(layout.primary, [QuickAction.buy, QuickAction.map]);
    expect(layout.more, [
      QuickAction.sell,
      QuickAction.pay,
      QuickAction.exchange,
      QuickAction.settings,
      QuickAction.support,
      QuickAction.priceHistory,
      QuickAction.transfer,
      QuickAction.history,
    ]);
    expect(selection.actions, [QuickAction.buy, QuickAction.map]);
  });

  test(
    'empty and filtered selections show Settings without rewriting favorites',
    () {
      for (final chosen in [
        <QuickAction>[],
        [QuickAction.buy],
      ]) {
        final selection = QuickActionSelection(chosen);
        final layout = QuickActionsLayout.resolve(
          available: walletActions,

          selection: selection,
        );
        expect(layout.primary, [QuickAction.settings]);
        expect(layout.more, [
          QuickAction.support,
          QuickAction.priceHistory,
          QuickAction.map,
          QuickAction.transfer,
          QuickAction.history,
        ]);
        expect(selection.actions, chosen);
      }
    },
  );

  test('Home keeps three actions and sends the fourth to More', () {
    final four = QuickActionsLayout.resolve(available: defaults.toSet());
    expect(four.primary, defaults.take(3));
    expect(four.more, [QuickAction.settings]);
    expect(four.primary.length + 1, QuickActionsLayout.maximumCells);
    final six = QuickActionsLayout.resolve(available: walletActions);
    expect(six.primary, defaults.take(3));
    expect(six.primary.length + 1, QuickActionsLayout.maximumCells);
  });
}
