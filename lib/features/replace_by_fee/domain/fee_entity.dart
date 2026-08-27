import 'package:bb_mobile/core/fees/domain/fees_entity.dart';

enum FeeType { fastest, economic, slow, custom }

/// Domain entity for RBF — pairs a [RelativeFee] with the preset it came from.
///
/// The fee rate is stored in BDK's native sat/kwu unit (via [RelativeFee])
/// so it survives down to the FFI boundary with zero rounding.
class FeeEntity {
  final FeeType type;
  final RelativeFee feeRate;

  const FeeEntity({required this.type, required this.feeRate});
}
