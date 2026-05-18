import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_constants.dart';
import 'base_robot.dart';

/// Robot for the wallet home screen (main screen after wallet creation).
///
/// Layout: Column → TopSection + Expanded(ScrollView[cards]) + BottomButtons
/// - Wallet cards (inside ScrollView): "Secure Bitcoin", "Instant payments"
/// - Bottom buttons (OUTSIDE ScrollView): "Receive", "Send"
/// - PopScope(canPop: false) — system back button is disabled
class WalletHomeRobot extends BaseRobot {
  WalletHomeRobot(super.$);

  /// Verify the home screen is visible (Receive + Send buttons present).
  Future<void> expectHomeVisible() async {
    final found = await waitForText(
      TestStrings.receive,
      timeout: TestTimeouts.standard,
    );
    expect(found, isTrue, reason: 'Wallet home screen did not appear');
    assertVisible(TestStrings.send);
  }

  /// Verify both default wallet cards are displayed.
  Future<void> expectWalletCards() async {
    final hasBitcoin = await waitForText(
      TestStrings.bitcoinWalletLabel,
      timeout: TestTimeouts.standard,
    );
    final hasLiquid = await waitForText(
      TestStrings.liquidWalletLabel,
      timeout: TestTimeouts.standard,
    );
    expect(hasBitcoin, isTrue,
        reason: 'Bitcoin wallet card ("${TestStrings.bitcoinWalletLabel}") not found');
    expect(hasLiquid, isTrue,
        reason: 'Liquid wallet card ("${TestStrings.liquidWalletLabel}") not found');
  }

  /// Tap the "Receive" button.
  ///
  /// Uses $.tester.tap() because the button is outside the ScrollView
  /// and may be obscured by the system navigation bar.
  Future<void> tapReceive() async {
    await tapText(TestStrings.receive);
    await $.pump(const Duration(seconds: 3));
  }

  /// Tap the "Send" button.
  Future<void> tapSend() async {
    await tapText(TestStrings.send);
    await $.pump(const Duration(seconds: 3));
  }

  /// Tap a specific wallet card by its label text.
  ///
  /// Cards are inside the ScrollView, so they should be hit-testable.
  /// Navigates to wallet detail screen.
  Future<void> tapWalletCard(String label) async {
    await tapText(label);
    await $.pump(const Duration(seconds: 3));
  }

  /// Verify we're NOT on the home screen (used after navigation).
  void expectNotOnHome() {
    // Home screen has both Receive and Send. If Receive is gone,
    // we've navigated away.
    assertGone(TestStrings.receive);
  }
}
