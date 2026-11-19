import 'package:bull_ui/bull_ui.dart' show BullButton, SingleChildScrollView;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Offset, Size;
import 'package:primitives/primitives.dart';

import 'ark_account_screen_test.dart' as wallet;
import 'ark_information_widget_test.dart' show app;

void main() {
  testWidgets('wallet payment actions stay visible together while scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = wallet.Client()..snapshot = Ok(wallet.observation());
    final cubit = wallet.controller(client);
    final calls = <String>[];
    await tester.pumpWidget(app(wallet.screen(cubit, calls)));
    await tester.pump();
    final receive = find.widgetWithText(BullButton, 'Receive');
    final send = find.widgetWithText(BullButton, 'Send');
    final receiveBefore = tester.getRect(receive);
    final sendBefore = tester.getRect(send);
    expect(receiveBefore.top, sendBefore.top);
    expect(receiveBefore.right, lessThan(sendBefore.left));
    expect(receiveBefore.bottom, lessThanOrEqualTo(844));
    expect(receive.hitTestable(), findsOneWidget);
    expect(send.hitTestable(), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(receive), receiveBefore);
    expect(tester.getRect(send), sendBefore);
    await tester.tap(receive);
    await tester.tap(send);
    expect(calls, ['receive', 'send']);
    expect(client.calls, ['read']);
  });
}
