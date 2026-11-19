import 'dart:ui' as ui;

import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:material_ui/material_ui.dart'
    show Builder, MediaQuery, TextScaler;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_screen_test.dart' show Rig;
import 'ark_information_widget_test.dart' show app, details;

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Board confirmation stays reachable at ${width.toInt()} pixels',
      (tester) async {
        tester.view.physicalSize = ui.Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final rig = Rig();
        await rig.cubit.prepare(Sats.fromInt(1000));
        await tester.pumpWidget(app(rig.screen));
        await tester.pumpAndSettle();

        final confirm = find.widgetWithText(BullButton, 'Confirm');
        expect(confirm.hitTestable(), findsOneWidget);
        final rect = tester.getRect(confirm);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(844));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rig.funding.calls, ['prepare', 'read']);
        await tester.tap(confirm.hitTestable());
        await tester.tap(confirm.hitTestable());
        await tester.pumpAndSettle();
        expect(rig.funding.calls, ['prepare', 'read', 'confirm']);
      },
    );
  }
  testWidgets('Board technical details expand at large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rig = Rig();
    await rig.cubit.prepare(Sats.fromInt(1000));
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: rig.screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('1' * 64), findsNothing);
    final expander = find.text('Transaction details');
    await tester.ensureVisible(expander);
    await tester.tap(expander);
    await tester.pumpAndSettle();
    expect(find.text('1' * 64), findsOneWidget);
    expect(find.text('2030-01-01T00:00:00.000Z'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(details(tester)['Fee rate (sat/vB)'], '2.0');
    expect(tester.takeException(), isNull);
    expect(rig.funding.calls, ['prepare', 'read']);
  });
}
