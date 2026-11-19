import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_payment_cubit_test.dart' show PaymentRig, destination;
import 'ark_payment_screen_test.dart' show action, input, frame, cancelAction;

ArkPaymentScreen page(PaymentRig rig, {Future<String?> Function()? scan}) =>
    ArkPaymentScreen(cubit: rig.cubit, onReconcile: () {}, onScan: scan);

void main() {
  testWidgets('address and amount steps stay local until explicit review', (
    tester,
  ) async {
    final rig = PaymentRig();
    await tester.pumpWidget(app(page(rig)));
    expect(find.byKey(const ValueKey('ark-payment-address')), findsOneWidget);
    expect(action(tester, 'Open the Camera').disabled, isTrue);
    final staleAddress = input(tester, 0).onChanged;
    staleAddress(destination);
    await frame(tester);
    action(tester, 'Continue').onPressed();
    await frame(tester);
    expect(find.byKey(const ValueKey('ark-payment-address')), findsNothing);
    expect(find.byKey(const ValueKey('ark-payment-amount')), findsOneWidget);
    expect(rig.client.calls, isEmpty);
    staleAddress('old-screen');
    input(tester, 1).onChanged('1000');
    await frame(tester);
    expect(rig.client.calls, isEmpty);
    // Android back returns to the address step without leaving the route.
    await tester.binding.handlePopRoute();
    await frame(tester);
    expect(input(tester, 0).value, destination);
    expect(rig.client.calls, isEmpty);
  });

  testWidgets('only one scan opens and a manual edit rejects its late result', (
    tester,
  ) async {
    final rig = PaymentRig();
    final reply = Completer<String?>();
    var scans = 0;
    Future<String?> scan() {
      ++scans;
      return reply.future;
    }

    await tester.pumpWidget(app(page(rig, scan: scan)));
    final open = action(tester, 'Open the Camera').onPressed;
    open();
    open();
    await frame(tester);
    expect(scans, 1);
    input(tester, 0).onChanged(destination);
    await frame(tester);
    reply.complete('late-scanner-value');
    await frame(tester);
    expect(input(tester, 0).value, destination);
    expect(action(tester, 'Open the Camera').disabled, isFalse);
    expect(rig.client.calls, isEmpty);
  });

  testWidgets('scan preserves raw text for the existing explicit parser', (
    tester,
  ) async {
    final rig = PaymentRig();
    const raw = '  lnbcrt1publicfixture  ';
    await tester.pumpWidget(app(page(rig, scan: () async => raw)));
    action(tester, 'Open the Camera').onPressed();
    await frame(tester);
    expect(input(tester, 0).value, raw);
    expect(rig.client.calls, isEmpty);
    action(tester, 'Continue').onPressed();
    await frame(tester);
    cancelAction(tester)();
    await frame(tester);
    expect(input(tester, 0).value, raw);
    expect(rig.client.calls, isEmpty);
  });

  for (final replacement in ['owner', 'scanner', 'dispose']) {
    testWidgets('late scan refuses $replacement replacement', (tester) async {
      final first = PaymentRig();
      final second = PaymentRig();
      final reply = Completer<String?>();
      Future<String?> scan() => reply.future;
      await tester.pumpWidget(app(page(first, scan: scan)));
      final oldOpen = action(tester, 'Open the Camera').onPressed;
      oldOpen();
      await frame(tester);
      switch (replacement) {
        case 'owner':
          await tester.pumpWidget(app(page(second, scan: scan)));
        case 'scanner':
          await tester.pumpWidget(app(page(first, scan: () async => null)));
        case 'dispose':
          await tester.pumpWidget(app(const SizedBox.shrink()));
      }
      reply.complete('obsolete');
      await frame(tester);
      oldOpen();
      await frame(tester);
      if (replacement != 'dispose') expect(input(tester, 0).value, '');
      expect(first.client.calls, isEmpty);
      expect(second.client.calls, isEmpty);
    });
  }

  testWidgets('cancelled or failed camera leaves manual entry available', (
    tester,
  ) async {
    final rig = PaymentRig();
    await tester.pumpWidget(app(page(rig, scan: () async => null)));
    action(tester, 'Open the Camera').onPressed();
    await frame(tester);
    expect(input(tester, 0).value, '');
    await tester.pumpWidget(
      app(page(rig, scan: () async => throw Exception('camera fixture'))),
    );
    action(tester, 'Open the Camera').onPressed();
    await frame(tester);
    expect(
      find.text("Camera is unavailable. Enter the recipient's address."),
      findsOneWidget,
    );
    input(tester, 0).onChanged(destination);
    await frame(tester);
    expect(input(tester, 0).value, destination);
    expect(rig.client.calls, isEmpty);
  });

  testWidgets('only a succeeded payment exposes Payment sent and Done', (
    tester,
  ) async {
    final rig = PaymentRig();
    for (final kind in ArkOperationKind.values) {
      rig.cubit.emit(
        ArkPaymentSubmitted(
          ArkOperation(
            id: 'actual-operation',
            kind: kind,
            status: ArkOperationStatus.succeeded,
            chainSource: Uri.parse('http://localhost:3000'),
            configGeneration: 1,
          ),
        ),
      );
      await tester.pumpWidget(app(page(rig)));
      await frame(tester);
      final count = kind == ArkOperationKind.payment
          ? findsOneWidget
          : findsNothing;
      expect(find.text('Payment sent'), count);
      expect(find.widgetWithText(BullButton, 'Done'), count);
      expect(
        find.text('actual-operation'),
        kind == ArkOperationKind.payment ? findsNothing : findsOneWidget,
      );
      expect(rig.client.calls, isEmpty);
    }
  });
}
