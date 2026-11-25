import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Widget switcher({required bool showingStatus, required List<String> taps}) =>
      wrapWithTheme(
        BullPaymentViewSwitch(
          showingStatus: showingStatus,
          statusLabel: 'Status',
          detailsLabel: 'Details',
          semanticsLabel: 'Views',
          onStatus: () => taps.add('status'),
          onDetails: () => taps.add('details'),
        ),
      );

  testWidgets('the shown view is the primary button', (tester) async {
    await tester.pumpWidget(switcher(showingStatus: true, taps: []));
    final buttons = tester
        .widgetList<BullToolButton>(find.byType(BullToolButton))
        .toList();
    expect(buttons.map((b) => b.label), ['Status', 'Details']);
    expect(buttons.map((b) => b.primary), [true, false]);

    await tester.pumpWidget(switcher(showingStatus: false, taps: []));
    final flipped = tester
        .widgetList<BullToolButton>(find.byType(BullToolButton))
        .toList();
    expect(flipped.map((b) => b.primary), [false, true]);
  });

  testWidgets('each button reports its own view', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(switcher(showingStatus: true, taps: taps));
    await tester.tap(find.text('Details'));
    await tester.tap(find.text('Status'));
    expect(taps, ['details', 'status']);
  });

  testWidgets('buttons are selected buttons and the group is named', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(switcher(showingStatus: true, taps: []));
    expect(
      tester.getSemantics(find.text('Status')),
      matchesSemantics(
        label: 'Status',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    expect(find.bySemanticsLabel('Views'), findsOneWidget);
    handle.dispose();
  });
}
