import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullBadge, BullQrCode, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Size;
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_receive_flow_test.dart' show controller;
import 'fake_ark_client.dart';

void main() {
  for (final kind in [ArkDestinationKind.ark, ArkDestinationKind.bolt11]) {
    testWidgets('ready $kind leads with its published kind and exact QR', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = FakeArkClient()
        ..destination = Ok(
          ArkReceiveDestination(
            kind: kind,
            value: 'public-layout-fixture-$kind',
          ),
        );
      final cubit = controller(client);
      addTearDown(cubit.close);
      await cubit.request(
        lightning: kind == ArkDestinationKind.bolt11,
        amount: '1000',
      );
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: cubit, onShare: (_) {})),
      );
      await tester.pumpAndSettle();
      final qr = tester.widget<BullQrCode>(find.byType(BullQrCode));
      expect(qr.size, 240);
      final square = find.byKey(const ValueKey('ark-receive-qr'));
      expect(tester.getSize(square), const Size(240, 240));
      expect(tester.getCenter(square).dx, 195);
      expect(qr.data, 'public-layout-fixture-$kind');
      final badge = tester.widget<BullBadge>(find.byType(BullBadge));
      expect(
        badge.label,
        kind == ArkDestinationKind.ark ? 'Ark' : 'Lightning invoice',
      );
      expect(
        tester.getTopLeft(find.byType(BullBadge)).dy,
        lessThan(tester.getTopLeft(find.byType(BullQrCode)).dy),
      );
      expect(tester.takeException(), isNull);
      expect(client.calls, ['receive']);
    });
  }
}
