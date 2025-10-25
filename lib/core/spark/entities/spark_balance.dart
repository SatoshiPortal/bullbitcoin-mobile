class SparkBalance {
  final int balanceSats;

  const SparkBalance({required this.balanceSats});

  int get totalSats => balanceSats;
}
