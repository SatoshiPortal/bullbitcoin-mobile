import 'package:bb_mobile/core/payjoin/domain/payjoin_session_window.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// An exchange payin is only accepted while its order is alive — the order
/// deadline is a handful of minutes. These tests pin the consequence: a payjoin
/// session bound to an order never outlives it, because a session that outlives
/// the order turns a failed negotiation into funds sent against a dead order.
void main() {
  final now = DateTime.utc(2026, 7, 28, 12);

  int? windowFor(Duration remaining) =>
      PayjoinSessionWindow.forOrderDeadline(now.add(remaining), now: now);

  group('inside the order window', () {
    test('a five minute order gives a five minute session', () {
      // The exchange's own receive session is 300s, aligned with the order.
      expect(windowFor(const Duration(minutes: 5)), 300);
    });

    test('the session shrinks as the deadline approaches', () {
      expect(windowFor(const Duration(minutes: 2)), 120);
      expect(windowFor(const Duration(seconds: 61)), 61);
    });

    test('exactly at the floor it is still attempted', () {
      expect(
        windowFor(const Duration(seconds: PayjoinConstants.minExpireAfterSec)),
        PayjoinConstants.minExpireAfterSec,
      );
    });
  });

  group('too late to attempt', () {
    test('under the floor payjoin is refused, not shortened', () {
      // The directory holds a long poll for ~30s, so a shorter session cannot
      // survive one cycle: it would only add a round trip before the inevitable
      // fallback, against an order about to expire.
      expect(windowFor(const Duration(seconds: 59)), isNull);
      expect(windowFor(const Duration(seconds: 1)), isNull);
    });

    test('an already expired order is refused', () {
      expect(windowFor(Duration.zero), isNull);
      expect(windowFor(const Duration(seconds: -30)), isNull);
      expect(windowFor(const Duration(days: -1)), isNull);
    });
  });

  group('the protocol ceiling still applies', () {
    test('a deadline beyond 24h is capped', () {
      // Never trust the deadline blindly: a schedule change or a clock skew
      // must not ask the PDK for a session it would refuse to build.
      expect(
        windowFor(const Duration(days: 3)),
        PayjoinConstants.maxExpireAfterSec,
      );
      expect(
        windowFor(const Duration(hours: 25)),
        PayjoinConstants.maxExpireAfterSec,
      );
    });

    test('exactly 24h is kept as is', () {
      expect(
        windowFor(const Duration(seconds: PayjoinConstants.maxExpireAfterSec)),
        PayjoinConstants.maxExpireAfterSec,
      );
    });
  });

  test('defaults to the real clock when no now is given', () {
    // The production call site passes no clock; a deadline comfortably ahead
    // must still produce a usable window.
    final window = PayjoinSessionWindow.forOrderDeadline(
      DateTime.now().add(const Duration(minutes: 5)),
    );

    expect(window, isNotNull);
    expect(window, greaterThan(PayjoinConstants.minExpireAfterSec));
    expect(window, lessThanOrEqualTo(300));
  });
}
