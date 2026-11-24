import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, SingleChildScrollView, ValueKey;
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
    final client = wallet.Client()
      ..snapshot = Ok(
        wallet.observation(
          movements: [
            for (var i = 0; i < 12; i++)
              ArkMovement(
                id: 'movement-$i',
                kind: ArkMovementKind.board,
                status: ArkMovementStatus.successful,
                amount: Sats.fromInt(1000 + i),
                createdAt: DateTime.utc(2026, 11, 4),
              ),
          ],
        ),
      );
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
    final cardBefore = tester.getTopLeft(
      find.byKey(const ValueKey('ark-wallet-balance')),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('ark-wallet-balance'))).dy,
      lessThan(cardBefore.dy),
    );
    expect(tester.getRect(receive), receiveBefore);
    expect(tester.getRect(send), sendBefore);
    await tester.tap(receive);
    await tester.tap(send);
    expect(calls, ['receive', 'send']);
    expect(client.calls, ['read']);
    expect(tester.takeException(), isNull);
  });
}
