import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28);

  test('normalizes an offset instant to UTC without changing it', () {
    final input = DateTime.parse('2020-03-02T01:30:00+02:00');
    final birthday = WalletBirthday(input, now: now);
    expect(birthday.dateTime, DateTime.utc(2020, 3, 1, 23, 30));
    expect(birthday.dateTime.isUtc, isTrue);
    expect(birthday, WalletBirthday(input.toUtc(), now: now));
  });

  test('accepts now but rejects any future instant before import', () {
    expect(WalletBirthday.tryCreate(now, now: now), isNotNull);
    final future = now.add(const Duration(microseconds: 1));
    expect(WalletBirthday.tryCreate(future, now: now), isNull);
    expect(() => WalletBirthday(future, now: now), throwsArgumentError);
  });
}
