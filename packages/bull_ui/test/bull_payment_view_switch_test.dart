import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets(
    'small scaled payment keeps both controls and content reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 457);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var selected = '';
      await tester.pumpWidget(
        wrapWithTheme(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 457),
              textScaler: TextScaler.linear(1.5),
            ),
            child: BullPaymentViews(
              showingStatus: true,
              switcher: BullPaymentViewSwitch(
                showingStatus: true,
                statusLabel: 'Transaction',
                detailsLabel: 'Details',
                semanticsLabel: 'Views',
                onStatus: () => selected = 'transaction',
                onDetails: () => selected = 'details',
              ),
              views: BullPaymentTransition(
                network: BullPaymentNetwork.bitcoin,
                phase: BullPaymentPhase.sending,
                status: 'Payment in progress',
                progress: BullPaymentProgress(
                  steps: [
                    'Payment detected',
                    'Negotiation',
                    'Broadcasted',
                    'Confirmed',
                  ],
                  completed: 2,
                ),
                onDone: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Details'));
      expect(selected, 'details');
      expect(tester.takeException(), isNull);
    },
  );

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

  group('BullPaymentViews', () {
    Widget views({required bool showingStatus, bool withSwitch = true}) =>
        wrapWithTheme(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.only(bottom: 30),
            ),
            child: BullPaymentViews(
              showingStatus: showingStatus,
              switcher: withSwitch
                  ? BullPaymentViewSwitch(
                      showingStatus: showingStatus,
                      statusLabel: 'Status',
                      detailsLabel: 'Details',
                      semanticsLabel: 'Views',
                      onStatus: () {},
                      onDetails: () {},
                    )
                  : null,
              views: Builder(
                builder: (context) => Text(
                  'inset ${MediaQuery.paddingOf(context).bottom}',
                  key: ValueKey(showingStatus),
                ),
              ),
            ),
          ),
        );

    testWidgets('the switch stays in place across views', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(views(showingStatus: true));
      final onStatus = tester.getRect(find.byType(BullPaymentViewSwitch));
      await tester.pumpWidget(views(showingStatus: false));
      final onDetails = tester.getRect(find.byType(BullPaymentViewSwitch));
      expect(onDetails, onStatus);
      // Centred, above the bottom inset.
      expect(onStatus.center.dx, closeTo(400 / 2, .5));
      expect(onStatus.bottom, lessThanOrEqualTo(800 - 30));
    });

    testWidgets('the strip takes the bottom inset, not the views', (
      tester,
    ) async {
      await tester.pumpWidget(views(showingStatus: true));
      expect(find.text('inset 0.0'), findsOneWidget);

      await tester.pumpWidget(views(showingStatus: true, withSwitch: false));
      expect(find.text('inset 30.0'), findsOneWidget);
      expect(find.byType(BullPaymentViewSwitch), findsNothing);
    });
  });
}
