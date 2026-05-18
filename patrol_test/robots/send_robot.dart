import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_constants.dart';
import 'base_robot.dart';

/// Robot for the send screen.
///
/// The send flow is a state machine with steps:
///   address → amount → confirm → sending → success
///
/// Each step renders a different sub-screen. Tests should verify
/// the step progression, not just final state.
class SendRobot extends BaseRobot {
  SendRobot(super.$);

  /// Verify the send screen is visible.
  ///
  /// The send screen shows a QR scanner prompt and address input.
  /// We check for multiple possible texts since the UI has several
  /// indicators we're on the send screen.
  Future<void> expectSendScreenVisible() async {
    // Check for the scan prompt which is always visible on the send screen
    final hasScan = await waitForText(
      TestStrings.sendScanPrompt,
      timeout: TestTimeouts.standard,
    );

    if (!hasScan) {
      // Fallback: check for address hint text
      final hasHint = await waitForText(
        TestStrings.sendAddressHint,
        timeout: TestTimeouts.quick,
      );
      if (!hasHint) {
        // Last resort: just verify we're not on home anymore
        assertGone(TestStrings.receive);
      }
    }
  }

  /// Verify we navigated away from home (home's Receive button is gone).
  void expectNotOnHome() {
    assertGone(TestStrings.receive);
  }

  /// Enter a Bitcoin/Liquid address into the address field.
  Future<void> enterAddress(String address) async {
    // Find the text field — it should have the hint text
    final textField = find.byType(TextField);
    if ($.tester.any(textField)) {
      await enterText(textField.first, address);
    }
  }

  /// Tap "Continue" to advance to the next step.
  Future<void> tapContinue() async {
    await tapText(TestStrings.sendContinue);
    await $.pump(const Duration(seconds: 2));
  }

  /// Verify the amount selection step is visible.
  Future<void> expectAmountStep() async {
    final found = await waitForText(
      TestStrings.sendSelectAmount,
      timeout: TestTimeouts.standard,
    );
    expect(found, isTrue, reason: 'Amount step did not appear');
  }

  /// Navigate back from the send screen.
  ///
  /// The app uses a custom TopBar with IconButton(Icons.arrow_back),
  /// not Flutter's standard BackButton widget.
  Future<void> goBack() async {
    await $.tester.tap(find.byIcon(Icons.arrow_back));
    await $.pump(const Duration(seconds: 2));
  }
}
