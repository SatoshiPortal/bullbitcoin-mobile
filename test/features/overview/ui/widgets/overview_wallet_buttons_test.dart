import 'package:bull_ui/bull_ui.dart' show BullReceiveSendButtons;
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, ScriptType;
import 'package:sync/sync.dart' show WalletKey;

void main() {
  testWidgets('watch-only keeps the exact Receive target but cannot send', (
    tester,
  ) async {
    final target = (
      key: WalletKey(id: 'watch', network: BitcoinNetwork.testnet),
      scriptType: ScriptType.bip49,
      signsLocally: false,
    );
    final receives = <OverviewReceiveTarget?>[];
    var current = true;
    await tester.pumpWidget(
      wrapWithTheme(
        OverviewWalletButtons.wallet(
          target: target,
          watchOnly: true,
          isCurrent: () => current,
          receiveLabel: 'Receive',
          sendLabel: 'Send',
          onReceive: receives.add,
          onSend: (_) => fail('Watch-only wallet must not send'),
        ),
      ),
    );
    final buttons = tester.widget<BullReceiveSendButtons>(
      find.byType(BullReceiveSendButtons),
    );
    expect(buttons.onSend, isNull);
    await tester.tap(find.text('Receive'));
    expect(receives, [target]);
    current = false;
    await tester.tap(find.text('Receive'));
    expect(receives, [target]);
  });

  testWidgets('Home alone emits the default Receive and Send destinations', (
    tester,
  ) async {
    final receives = <OverviewReceiveTarget?>[];
    final sends = <WalletKey?>[];
    await tester.pumpWidget(
      wrapWithTheme(
        OverviewWalletButtons.home(
          receiveLabel: 'Receive',
          sendLabel: 'Send',
          onReceive: receives.add,
          onSend: sends.add,
        ),
      ),
    );
    await tester.tap(find.text('Receive'));
    await tester.tap(find.text('Send'));
    expect(receives, [null]);
    expect(sends, [null]);
  });

  testWidgets('wallet Send emits the exact key and rejects revoked taps', (
    tester,
  ) async {
    final key = WalletKey(id: 'same', network: BitcoinNetwork.regtest);
    final sends = <WalletKey?>[];
    var admitted = true;
    await tester.pumpWidget(
      wrapWithTheme(
        OverviewWalletButtons.wallet(
          target: (key: key, scriptType: ScriptType.bip84, signsLocally: true),
          watchOnly: false,
          isCurrent: () => admitted,
          receiveLabel: 'Receive',
          sendLabel: 'Send',
          onReceive: (_) {},
          onSend: sends.add,
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    expect(sends, [key]);
    admitted = false;
    await tester.tap(find.text('Send'));
    expect(sends, [key]);
  });
}
