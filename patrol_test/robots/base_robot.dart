import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/test_constants.dart';

/// Base class for all Robot classes in the test suite.
///
/// Encapsulates the PatrolIntegrationTester and provides common
/// interaction patterns that work reliably with this app:
///   - Polling loops instead of pumpAndSettle (background tasks never settle)
///   - $.tester.tap() instead of $().tap() (bypasses hit-test for obscured widgets)
///   - Text-based finders sourced from TestStrings constants
abstract class BaseRobot {
  BaseRobot(this.$);

  final PatrolIntegrationTester $;

  // ── Waiting ──────────────────────────────────────────────

  /// Poll until [text] appears in the widget tree, or timeout.
  Future<bool> waitForText(
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

  /// Poll until a widget of [type] appears, or timeout.
  Future<bool> waitForType(
    Type type, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      await $.pump(TestTimeouts.pumpInterval);
      if ($.tester.any(find.byType(type))) return true;
    }
    return false;
  }

  /// Poll until a widget with [key] appears, or timeout.
  Future<bool> waitForKey(
    Key key, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      await $.pump(TestTimeouts.pumpInterval);
      if ($.tester.any(find.byKey(key))) return true;
    }
    return false;
  }

  // ── Tapping ──────────────────────────────────────────────

  /// Tap a widget containing [text].
  ///
  /// Uses $.tester.tap() which bypasses Patrol's hit-test check.
  /// This is necessary because buttons at the bottom of the screen
  /// (like Receive/Send) are often obscured by the navigation bar.
  Future<void> tapText(String text) async {
    await $.tester.tap(find.text(text));
    await $.pump(const Duration(milliseconds: 500));
  }

  /// Tap a widget identified by [key].
  Future<void> tapByKey(Key key) async {
    await $.tester.tap(find.byKey(key));
    await $.pump(const Duration(milliseconds: 500));
  }

  /// Tap a widget of [type].
  Future<void> tapByType(Type type) async {
    await $.tester.tap(find.byType(type));
    await $.pump(const Duration(milliseconds: 500));
  }

  // ── Assertions ───────────────────────────────────────────

  /// Assert that [text] is visible in the widget tree right now.
  void assertVisible(String text) {
    expect($.tester.any(find.text(text)), isTrue,
        reason: '"$text" not found in widget tree');
  }

  /// Assert that [text] is NOT in the widget tree right now.
  void assertGone(String text) {
    expect($.tester.any(find.text(text)), isFalse,
        reason: '"$text" unexpectedly found in widget tree');
  }

  /// Assert that a widget of [type] exists in the tree.
  void assertTypeVisible(Type type) {
    expect($.tester.any(find.byType(type)), isTrue,
        reason: '$type not found in widget tree');
  }

  // ── Text entry ───────────────────────────────────────────

  /// Enter text into a field identified by [finder].
  Future<void> enterText(Finder finder, String text) async {
    await $.tester.enterText(finder, text);
    await $.pump(const Duration(milliseconds: 500));
  }
}
