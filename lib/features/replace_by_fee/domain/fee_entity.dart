enum FeeType { fastest, economic, slow, custom }

class FeeEntity {
  final FeeType type;
  final double feeRate;

  const FeeEntity({required this.type, required this.feeRate});
}
