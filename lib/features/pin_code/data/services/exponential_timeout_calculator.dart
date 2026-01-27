import 'package:bb_mobile/features/pin_code/domain/services/timeout_calculator.dart';

class ExponentialTimeoutCalculator implements TimeoutCalculator {
  final int timeoutMultiplier; // In seconds

  ExponentialTimeoutCalculator({this.timeoutMultiplier = 30});

  @override
  int calculateTimeout(int attempts) {
    if (attempts <= 3) return 0;
    return (attempts - 3) * timeoutMultiplier;
  }
}
