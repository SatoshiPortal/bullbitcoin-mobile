/// A known wallet creation instant, normalized to UTC and never in the future.
/// An unknown birthday is represented by a nullable WalletBirthday.
final class WalletBirthday {
  final DateTime dateTime;

  factory WalletBirthday(DateTime value, {DateTime? now}) {
    final birthday = tryCreate(value, now: now);
    if (birthday == null) {
      throw ArgumentError.value(value, 'value', 'birthday is in the future');
    }
    return birthday;
  }

  const WalletBirthday._(this.dateTime);

  /// Non-throwing validation for user input, before creating any wallet state.
  static WalletBirthday? tryCreate(DateTime value, {DateTime? now}) {
    final utc = value.toUtc();
    return utc.isAfter((now ?? DateTime.now()).toUtc())
        ? null
        : WalletBirthday._(utc);
  }

  @override
  bool operator ==(Object other) =>
      other is WalletBirthday && dateTime == other.dateTime;

  @override
  int get hashCode => dateTime.hashCode;
}
