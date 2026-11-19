import 'package:bb_mobile/features/wallet/data/ark_source_label.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../../features/ark/test/ark_board_screen_test.dart' show Rig;
import '../../../../features/ark/test/support/ark_host_component_probes.dart'
    show labelledBoardFixture;
import '../../../../features/ark/test/ark_information_widget_test.dart'
    show app;

void main() {
  test('same-account source replacement cannot publish the old ID label', () {
    final labels = ArkSourceLabelCache()..observe('source-a', 'First source');
    expect(labels.read('source-a'), 'First source');
    labels.observe('source-b', 'Second source');
    expect(labels.read('source-a'), isNull);
    expect(labels.read('source-b'), 'Second source');
  });
  testWidgets('a label for another source does not replace the actual source', (
    tester,
  ) async {
    final rig = Rig();
    await rig.cubit.prepare(Sats.fromInt(1000));
    await tester.pumpWidget(
      app(
        labelledBoardFixture(
          rig,
          sourceLabel: (walletId: 'source-wallet', label: 'Current source'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Current source'), findsOneWidget);
    await tester.pumpWidget(
      app(
        labelledBoardFixture(
          rig,
          sourceLabel: (walletId: 'replaced-source', label: 'Retired source'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retired source'), findsNothing);
    expect(find.text('Current source'), findsNothing);
    expect(
      tester
          .widget<BullButton>(find.widgetWithText(BullButton, 'Confirm'))
          .disabled,
      false,
    );
    expect(rig.funding.calls, ['prepare', 'read']);
  });
}
