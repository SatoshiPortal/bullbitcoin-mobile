// Keep new Send tests independent of the application package namespace.
// ignore: avoid_relative_lib_imports
import '../../../../lib/features/send/ui/widgets/send_whole_balance_dialog.dart';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('MAX facts remain exact and acceptance can be disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: testBullExtensions,
          textTheme: testBullTypography.toTextTheme(),
        ),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: BullDialog(
              child: SendWholeBalanceDialog(
                title: 'Send your whole balance?',
                description: 'The network fee is taken from it.',
                balanceLabel: 'Balance',
                balance: const Text('100,000 sats'),
                feeLabel: 'Network fee · Fast',
                fee: const Text('− 200 sats'),
                receivesLabel: 'Recipient gets',
                receives: const Text('99,800 sats'),
                cancelLabel: 'Cancel',
                sendAllLabel: 'Send all',
                onCancel: () => cancelled = true,
                onSendAll: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('99,800 sats'), findsOneWidget);
    final send = tester.widget<BullButton>(find.byType(BullButton).last);
    expect(send.disabled, isTrue);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
