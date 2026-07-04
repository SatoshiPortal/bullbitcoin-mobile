/// LNURLp metadata for a Bull Lightning address: the advertised payment
/// methods and the callback endpoint that mints a payment target.
class LiquidDirectPayMetadata {
  final List<String> paymentMethods;
  final Uri callback;

  const LiquidDirectPayMetadata({
    required this.paymentMethods,
    required this.callback,
  });
}

/// Result of the LUD-22 callback. Models all three server shapes:
/// - success: `{"L-BTC": {"address": ...}}` → [liquidAddress] set;
/// - soft-limit fallback: `{"pr": ...}` (a Lightning invoice) → [bolt11] set;
///   the client declines this and routes the normal swap (DG-8);
/// - error envelope: HTTP 200 `{"status":"ERROR","code":...,"reason":...,
///   "details":{"min_sat":...}}` → [status]/[code]/[reason]/[minSat] set.
class LiquidDirectPayCallbackResult {
  final String? status;
  final String? code;
  final String? reason;
  final int? minSat;
  final String? liquidAddress;
  final String? bolt11;

  const LiquidDirectPayCallbackResult({
    this.status,
    this.code,
    this.reason,
    this.minSat,
    this.liquidAddress,
    this.bolt11,
  });
}

/// Capability port for the payer-side LUD-22 direct-pay flow. It wraps exactly
/// one external system — the recipient's LNURLp server — and owns no entity, so
/// it is a `Port`, not a repository (charter §2.1).
abstract interface class LiquidDirectPayPort {
  Future<LiquidDirectPayMetadata> fetchMetadata(Uri metadataUrl);

  Future<LiquidDirectPayCallbackResult> requestLiquidPayment(
    Uri callback, {
    required Map<String, String> query,
  });
}
