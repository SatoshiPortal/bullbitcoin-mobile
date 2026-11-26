import 'package:ark/ark.dart';
import 'package:bull_ark/ark_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_module_composition_test.dart' show Rig;
import 'ark_operations_test.dart' show account;

void main() {
  testWidgets(
    'cooperative transfer quotes Bitcoin without submitting or starting an emergency exit',
    (tester) async {
      final rig = Rig();
      rig.client.quoted = Ok(
        ArkQuote(
          id: 'cooperative-quote',
          account: account(),
          generation: 2,
          chainSource: Uri.parse('https://chain.example'),
          configGeneration: 1,
          kind: ArkOperationKind.payment,
          amount: Sats.fromInt(1100),
          fee: Sats.fromInt(100),
          net: Sats.fromInt(1000),
          destination: 'bcrt1publicfixture',
          destinationKind: ArkDestinationKind.bitcoin,
          observedTip: 100,
          validUntil: DateTime.utc(2030),
        ),
      );
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      final entry = ArkTransferPaymentEntry(
        account: account(),
        destination: 'bcrt1publicfixture',
        amount: Sats.fromInt(1000),
      );
      rig.router.go('/ark/review', extra: entry);
      await tester.pumpAndSettle();
      final requests = rig.client.arguments
          .whereType<(ArkAccountId, ArkQuoteRequest)>();
      expect(requests, hasLength(1));
      final request = requests.single.$2 as ArkPaymentQuoteRequest;
      expect(request.destination.kind, ArkDestinationKind.bitcoin);
      expect(request.amount, Sats.fromInt(1000));
      expect(rig.client.calls.where((call) => call == 'submit'), isEmpty);
      expect(entry.consumed, isTrue);
      // Returning to the same input is never another quote or funding intent.
      rig.router.go('/');
      await tester.pumpAndSettle();
      rig.router.go('/ark/review', extra: entry);
      await tester.pumpAndSettle();
      expect(rig.client.calls.where((call) => call == 'quote'), hasLength(1));
    },
  );

  testWidgets('transfer Board refuses a host without explicit source binding', (
    tester,
  ) async {
    final rig = Rig();
    await tester.pumpWidget(rig.app());
    await tester.pumpAndSettle();
    final entry = ArkTransferBoardEntry(
      account: account(),
      sourceWalletId: 'source-wallet',
      amount: Sats.fromInt(1000),
    );
    rig.router.go('/ark/board', extra: entry);
    await tester.pumpAndSettle();
    expect(entry.consumed, isTrue);
    expect(rig.boardFunding.calls, isEmpty);
    expect(rig.client.calls.where((call) => call == 'submit'), isEmpty);
  });
}
