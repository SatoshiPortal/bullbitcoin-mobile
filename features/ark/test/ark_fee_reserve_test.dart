import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullCopyField, BullFieldAction, BullQrCode, ValueKey;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app, config;
import 'ark_operations_test.dart' show account;

const address = 'bcrt1qpublicreserveaddressfixture';

void main() {
  testWidgets('foreign account reserve is not offered as a funding address', (
    tester,
  ) async {
    final owner = account();
    final snapshot = ArkSnapshot(
      account: ArkAccountId(
        parent: owner.parent,
        network: owner.network,
        serverIdentity: 'foreign-public-server',
      ),
      revision: 2,
      observedAt: DateTime.utc(2026, 11, 18),
      confirmedReserve: Sats.fromInt(100),
      reserveAddress: 'bcrt1qforeignpublicfixture',
    );
    await tester.pumpWidget(
      app(ArkInformationScreen(snapshot: snapshot, config: config())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BullCopyField), findsNothing);
    expect(find.byType(BullQrCode), findsNothing);
  });

  for (final amount in [null, 0, 1234]) {
    testWidgets(
      'fee reserve exposes the observed amount $amount and exact address',
      (tester) async {
        final snapshot = ArkSnapshot(
          account: account(),
          revision: 2,
          observedAt: DateTime.utc(2026, 11, 18),
          confirmedReserve: amount == null ? null : Sats.fromInt(amount),
          reserveAddress: address,
        );
        await tester.pumpWidget(
          app(ArkInformationScreen(snapshot: snapshot, config: config())),
        );
        await tester.pumpAndSettle();
        expect(find.text('On-chain fee reserve'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('ark-fee-reserve')),
            matching: find.text(
              amount == null ? 'Unavailable' : '$amount sats',
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Fund this address'), findsOneWidget);
        final field = tester.widget<BullCopyField>(find.byType(BullCopyField));
        expect(field.text, address);
        expect(field.clipboardText ?? field.text, address);
        expect(
          tester.widget<BullQrCode>(find.byType(BullQrCode)).data,
          address,
        );
        MethodCall? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') copied = call;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final copy = find.descendant(
          of: find.byType(BullCopyField),
          matching: find.byType(BullFieldAction),
        );
        await tester.ensureVisible(copy);
        await tester.tap(copy);
        await tester.pump();
        expect(copied?.arguments, {'text': address});
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
    );
  }

  for (final absent in [null, '', '   ']) {
    testWidgets(
      'absent reserve address $absent hides the whole funding section',
      (tester) async {
        final snapshot = ArkSnapshot(
          account: account(),
          revision: 2,
          observedAt: DateTime.utc(2026, 11, 18),
          confirmedReserve: Sats.zero,
          reserveAddress: absent,
        );
        await tester.pumpWidget(
          app(ArkInformationScreen(snapshot: snapshot, config: config())),
        );
        await tester.pumpAndSettle();
        expect(find.text('On-chain fee reserve'), findsNothing);
        expect(find.byType(BullCopyField), findsNothing);
        expect(find.byType(BullQrCode), findsNothing);
      },
    );
  }
}
