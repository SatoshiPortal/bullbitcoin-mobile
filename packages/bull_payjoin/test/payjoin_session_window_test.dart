import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 20, 12);
  Duration? windowFor(Duration remaining) =>
      PayjoinSessionWindow.forOrderDeadline(now.add(remaining), now: now);

  // On testnet the original was broadcast three seconds after the exchange had
  // already expired the order: the window must end early enough for the
  // fallback to land while the order still accepts it.
  test('the window leaves the fallback reserve before the deadline', () {
    expect(
      windowFor(const Duration(seconds: 280)),
      const Duration(seconds: 190),
    );
  });

  test('a window shorter than the minimum session is no window', () {
    expect(
      windowFor(const Duration(seconds: 150)),
      const Duration(seconds: 60),
    );
    expect(windowFor(const Duration(seconds: 149)), isNull);
  });

  test('a passed deadline is no window', () {
    expect(windowFor(const Duration(seconds: -1)), isNull);
  });

  test('a far deadline is capped at the maximum session', () {
    expect(
      windowFor(const Duration(days: 3)),
      PayjoinPolicy.maximumSessionLifetime,
    );
  });
}
