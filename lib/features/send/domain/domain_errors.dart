import 'package:bb_mobile/core/errors/bull_exception.dart';

/// Failed to read the discounted vsize of a Liquid PSET — typically because
/// the underlying LWK call rejected the input or the network round-trip
/// errored out.
class CalculateLiquidPsetSizeException extends BullException {
  CalculateLiquidPsetSizeException(super.message);
}
