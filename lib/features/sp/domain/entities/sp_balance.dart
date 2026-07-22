/// Pure domain value object for the unified Silent Payments balance.
class SpBalance {
  final BigInt confirmedSat;
  final BigInt totalUnifiedSat;

  const SpBalance({required this.confirmedSat, required this.totalUnifiedSat});
}
