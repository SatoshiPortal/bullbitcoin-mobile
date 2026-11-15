/// How often the user asks the system to check for incoming payments. The
/// system may delay or skip a check; [off] cancels background checks.
enum BackgroundSyncInterval {
  minutes15(Duration(minutes: 15)),
  minutes30(Duration(minutes: 30)),
  hour1(Duration(hours: 1)),
  hours6(Duration(hours: 6)),
  hours24(Duration(hours: 24)),
  off(null);

  final Duration? frequency;

  const BackgroundSyncInterval(this.frequency);

  static const fallback = hour1;
}
