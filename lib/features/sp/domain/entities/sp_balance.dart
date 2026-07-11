import 'package:bull_sdk/bwk.dart';

/// Pure domain value object for the unified Silent Payments balance.
class SpBalance {
  final BigInt confirmedSat;
  final BigInt totalUnifiedSat;

  const SpBalance({required this.confirmedSat, required this.totalUnifiedSat});

  factory SpBalance.fromView(SpBalanceView view) => SpBalance(
    confirmedSat: view.confirmedSat,
    totalUnifiedSat: view.totalUnifiedSat,
  );
}
