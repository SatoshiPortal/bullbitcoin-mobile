import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_payment_cubit_test.dart' show PaymentRig, destination;
import 'ark_payment_screen_test.dart' show action, input, frame;
import 'ark_receive_flow_test.dart' as receive;
import 'fake_ark_client.dart';

void main() {
  testWidgets(
    'MAX copies exact Ark sats locally and refuses an obsolete balance',
    (tester) async {
      final rig = PaymentRig();
      final balance = Sats(BigInt.parse('9007199254740993'));
      Widget page(Sats? amount) => app(
        ArkPaymentScreen(
          cubit: rig.cubit,
          initialDestination: destination,
          observedSpendable: amount,
          onReconcile: () {},
        ),
      );
      await tester.pumpWidget(page(balance));
      final oldMax = action(tester, 'MAX').onPressed;
      expect(action(tester, 'MAX').disabled, isFalse);
      oldMax();
      await frame(tester);
      expect(input(tester, 1).value, '9,007,199,254,740,993');
      expect(rig.client.calls, isEmpty);
      await tester.pumpWidget(page(Sats.fromInt(1234)));
      input(tester, 1).onChanged('42');
      await frame(tester);
      oldMax();
      await frame(tester);
      expect(input(tester, 1).value, '42');
      action(tester, 'MAX').onPressed();
      await frame(tester);
      expect(input(tester, 1).value, '1,234');
      expect(rig.client.calls, isEmpty);
      await tester.pumpWidget(page(null));
      expect(action(tester, 'MAX').disabled, isTrue);
    },
  );

  testWidgets('old MAX cannot edit a replacement owner or disposed screen', (
    tester,
  ) async {
    final first = PaymentRig();
    final next = PaymentRig();
    Widget page(PaymentRig rig) => app(
      ArkPaymentScreen(
        cubit: rig.cubit,
        initialDestination: destination,
        observedSpendable: Sats.fromInt(5000),
        onReconcile: () {},
      ),
    );
    await tester.pumpWidget(page(first));
    final oldMax = action(tester, 'MAX').onPressed;
    await tester.pumpWidget(page(next));
    oldMax();
    await frame(tester);
    expect(input(tester, 1).value, '');
    final currentMax = action(tester, 'MAX').onPressed;
    await tester.pumpWidget(app(const SizedBox.shrink()));
    currentMax();
    expect(first.client.calls, isEmpty);
    expect(next.client.calls, isEmpty);
  });

  testWidgets('confirmation uses the primary theme pair', (tester) async {
    final rig = PaymentRig();
    await rig.ready();
    await tester.pumpWidget(
      app(ArkPaymentScreen(cubit: rig.cubit, onReconcile: () {})),
    );
    final button = action(tester, 'Confirm');
    final context = tester.element(find.widgetWithText(BullButton, 'Confirm'));
    expect(button.bgColor, context.bull.primary);
    expect(button.textColor, context.bull.onPrimary);
    expect(button.outlined, isFalse);
    final table = tester.widget<BullDetailsTable>(
      find.byType(BullDetailsTable),
    );
    expect(table.flat, isTrue);
    final rows = table.items.whereType<BullDetailsTableItem>().toList();
    expect(
      rows.singleWhere((row) => row.label == 'Total').displayValue,
      '1,000 sats',
    );
    final recipient = rows.singleWhere((row) => row.label == 'To');
    expect(recipient.copyValue, destination);
    final text = recipient.displayWidget;
    expect(text, isA<BullText>());
    if (text is BullText) {
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    }
  });

  testWidgets(
    'Receive stays passive and ready QR has no extra generation step',
    (tester) async {
      final client = FakeArkClient()
        ..destination = Ok(
          ArkReceiveDestination(
            kind: ArkDestinationKind.ark,
            value: 'public-parity-address',
          ),
        );
      final cubit = receive.controller(client);
      addTearDown(cubit.close);
      Widget page() => app(ArkReceiveScreen(cubit: cubit));
      await tester.pumpWidget(page());
      await tester.pumpWidget(page());
      expect(client.calls, isEmpty);
      expect(find.widgetWithText(BullButton, 'Create request'), findsOneWidget);
      await cubit.request(lightning: false, amount: '');
      await frame(tester);
      expect(
        tester.widget<BullQrCode>(find.byType(BullQrCode)).data,
        'public-parity-address',
      );
      expect(find.widgetWithText(BullButton, 'Create request'), findsNothing);
      await tester.pumpWidget(page());
      expect(client.calls, ['receive']);
    },
  );
  for (final replacement in ['ready', 'closed']) {
    testWidgets(
      'address Copy writes once while active and rejects $replacement callback',
      (tester) async {
        final writes = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              if (call.arguments case {'text': final String text}) {
                writes.add(text);
              }
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final client = FakeArkClient()
          ..destination = Ok(
            ArkReceiveDestination(
              kind: ArkDestinationKind.ark,
              value: 'public-first-address',
            ),
          );
        final cubit = receive.controller(client);
        addTearDown(cubit.close);
        await cubit.request(lightning: false, amount: '');
        await tester.pumpWidget(app(ArkReceiveScreen(cubit: cubit)));
        await tester.tap(
          find.byKey(const ValueKey('ark-receive-address-actions')),
        );
        await tester.pumpAndSettle();
        final oldCopy = action(tester, 'Copy').onPressed;
        oldCopy();
        await frame(tester);
        expect(writes, ['public-first-address']);
        if (replacement == 'ready') {
          client.destination = Ok(
            ArkReceiveDestination(
              kind: ArkDestinationKind.ark,
              value: 'public-replacement-address',
            ),
          );
          await cubit.request(lightning: false, amount: '');
          await frame(tester);
        } else {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.widgetWithText(BullButton, 'Copy'), findsNothing);
        }
        oldCopy();
        await frame(tester);
        expect(writes, ['public-first-address']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
