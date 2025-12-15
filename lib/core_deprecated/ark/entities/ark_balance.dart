class ArkBalance {
  final int preconfirmed;
  final int settled;
  final int available;
  final int recoverable;
  final int total;
  final ArkBoarding boarding;

  const ArkBalance({
    required this.preconfirmed,
    required this.settled,
    required this.available,
    required this.recoverable,
    required this.total,
    required this.boarding,
  });

  int get completeTotal => boarding.total + total;
}

class ArkBoarding {
  final int unconfirmed;
  final int confirmed;
  final int total;

  const ArkBoarding({
    required this.unconfirmed,
    required this.confirmed,
    required this.total,
  });
}
