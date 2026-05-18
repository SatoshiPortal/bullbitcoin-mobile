import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_constants.dart';

/// Pump frames until a widget with [text] appears, or timeout.
///
/// Returns true if found, false if timed out. This replaces
/// pumpAndSettle() which NEVER works for this app because of
/// perpetual background tasks (workmanager, price polling, swap watchers).
Future<bool> waitForText(
  PatrolIntegrationTester $,
  String text, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    await $.pump(TestTimeouts.pumpInterval);
    if ($.tester.any(find.text(text))) return true;
  }
  return false;
}

/// Wait for ANY of the given texts to appear.
/// Returns the first matching text, or null on timeout.
Future<String?> waitForAnyText(
  PatrolIntegrationTester $,
  List<String> texts, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    await $.pump(TestTimeouts.pumpInterval);
    for (final text in texts) {
      if ($.tester.any(find.text(text))) return text;
    }
  }
  return null;
}

/// Launch app, create wallet, wait for home screen.
///
/// This is the standard setup for any test that needs a wallet.
/// Each Patrol test gets a fresh app install, so every test that
/// goes beyond onboarding must call this.
Future<void> launchAndCreateWallet(PatrolIntegrationTester $) async {
  app.main();
  final onboarding = await waitForText(
    $,
    TestStrings.createNewWallet,
    timeout: TestTimeouts.standard,
  );
  expect(onboarding, isTrue, reason: 'Onboarding did not appear');

  // Tap "Create New Wallet" — use $.tester.tap to bypass hit-test
  await $.tester.tap(find.text(TestStrings.createNewWallet));
  await $.pump(const Duration(seconds: 2));

  // Wait for home screen — "Receive" button indicates we're there
  final home = await waitForText(
    $,
    TestStrings.receive,
    timeout: TestTimeouts.walletCreation,
  );
  expect(home, isTrue, reason: 'Wallet home did not appear after creation');
}
