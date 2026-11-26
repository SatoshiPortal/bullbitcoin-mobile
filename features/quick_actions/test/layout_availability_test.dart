import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

const defaults = [
  QuickAction.settings,
  QuickAction.history,
  QuickAction.transfer,
  QuickAction.toggleAmounts,
];
const walletActions = {...defaults, QuickAction.map};

void main() {
  test('OFF keeps More with amount visibility and Map', () {
    final layout = QuickActionsLayout.resolve(available: walletActions);
    expect(layout.primary, defaults.take(3));
    expect(layout.more, [QuickAction.toggleAmounts, QuickAction.map]);
  });

  test('ON prioritizes exchange then app controls then hidden favorites', () {
    final selection = QuickActionSelection([QuickAction.pay, QuickAction.map]);
    final layout = QuickActionsLayout.resolve(
      available: QuickAction.values.toSet(),

      selection: selection,
    );
    expect(layout.primary, [QuickAction.pay, QuickAction.map]);
    expect(layout.more, [
      QuickAction.exchange,
      QuickAction.toggleAmounts,
      QuickAction.support,
      QuickAction.priceHistory,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
    ]);
    expect(selection.actions, [QuickAction.pay, QuickAction.map]);
  });

  test('empty and filtered selections keep all actions in More', () {
    for (final chosen in [
      <QuickAction>[],
      [QuickAction.pay],
    ]) {
      final selection = QuickActionSelection(chosen);
      final layout = QuickActionsLayout.resolve(
        available: walletActions,

        selection: selection,
      );
      expect(layout.primary, isEmpty);
      expect(layout.more, [
        QuickAction.toggleAmounts,
        QuickAction.map,
        QuickAction.transfer,
        QuickAction.history,
        QuickAction.settings,
      ]);
      expect(selection.actions, chosen);
    }
  });

  test('Home keeps three actions and sends the fourth to More', () {
    final four = QuickActionsLayout.resolve(available: defaults.toSet());
    expect(four.primary, defaults.take(3));
    expect(four.more, [QuickAction.toggleAmounts]);
    expect(four.primary.length + 1, QuickActionsLayout.maximumCells);
    final five = QuickActionsLayout.resolve(available: walletActions);
    expect(five.primary, defaults.take(3));
    expect(five.more, [QuickAction.toggleAmounts, QuickAction.map]);
    expect(five.primary.length + 1, QuickActionsLayout.maximumCells);
  });
}
