import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('dispatches receive and send independently', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(
      wrapWithTheme(
        BullReceiveSendButtons(
          receiveLabel: 'Receive',
          sendLabel: 'Send',
          onReceive: () => actions.add('receive'),
          onSend: () => actions.add('send'),
        ),
      ),
    );

    await tester.tap(find.text('Receive'));
    await tester.tap(find.text('Send'));

    expect(actions, ['receive', 'send']);
  });

  testWidgets('keeps receive available when send is disabled', (tester) async {
    var receives = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        BullReceiveSendButtons(
          receiveLabel: 'Receive',
          sendLabel: 'Send',
          onReceive: () => receives++,
          onSend: null,
        ),
      ),
    );

    expect(
      tester
          .widget<BullButton>(find.widgetWithText(BullButton, 'Send'))
          .disabled,
      isTrue,
    );
    await tester.tap(find.text('Receive'));
    expect(receives, 1);
  });
}
