enum PriceHistoryInterval {
  fifteenMinutes('fifteen', Duration(minutes: 15)),
  day('day', Duration(days: 90));

  final String code;
  final Duration window;

  const PriceHistoryInterval(this.code, this.window);
}
