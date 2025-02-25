abstract class TimeoutCalculator {
  int calculateTimeout(int attempts);
}

class ExponentialTimeoutCalculator implements TimeoutCalculator {
  final int timeoutMultiplier; // In seconds

  ExponentialTimeoutCalculator({this.timeoutMultiplier = 30});

  @override
  int calculateTimeout(int attempts) {
    if (attempts <= 3) return 0;
    return (attempts - 3) * timeoutMultiplier;
  }
}
