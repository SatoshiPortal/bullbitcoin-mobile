import 'package:primitives/primitives.dart' show ConvertAmount, FormatAmount;

class FeeUi {
  final String Function(int) formatSats;
  final String Function(num) formatApproximateSats;
  final double Function(int, double) satsToFiat;

  static const standard = FeeUi(
    formatSats: FormatAmount.sats,
    formatApproximateSats: FormatAmount.satsApprox,
    satsToFiat: ConvertAmount.satsToFiat,
  );

  const FeeUi({
    required this.formatSats,
    required this.formatApproximateSats,
    required this.satsToFiat,
  });
}
