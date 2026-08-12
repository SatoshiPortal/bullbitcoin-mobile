import 'package:freezed_annotation/freezed_annotation.dart';

part 'fees_entity.freezed.dart';

/// A fee paid for a Bitcoin or Liquid transaction.
///
/// Two variants exist because the user can input either:
/// - an absolute amount of satoshis they want to pay (regardless of tx size),
/// - or a fee rate in sat/vByte (which the wallet multiplies by the actual
///   tx vsize when building the transaction).
///
/// At the SDK boundary:
/// - BDK's `TxBuilder` accepts both via `feeAbsolute()` and `feeRate()`.
/// - BDK's `BumpFeeTxBuilder` (RBF) accepts ONLY a fee rate.
/// - LWK's `buildLbtcTx` accepts ONLY a fee rate.
///
/// For the rate variant we store the value in BDK's native unit — sat per
/// kilo-weight-unit (kwu) — which lets us hit the SDK with zero conversion
/// and supports fee rates well below 1 sat/vByte without precision loss.
/// 1 vByte = 4 weight units, so 1 sat/vByte = 250 sat/kwu.
@freezed
sealed class NetworkFee with _$NetworkFee {
  const NetworkFee._();

  /// An absolute fee in satoshis.
  const factory NetworkFee.absolute(int sats) = AbsoluteFee;

  /// A relative fee stored in BDK's native unit (sat per kilo-weight-unit).
  ///
  /// Prefer [NetworkFee.relativeFromSatPerVbyte] for code that reasons in
  /// the user-facing sat/vByte unit. This constructor exists to keep
  /// well-known defaults `const`-able (e.g. `0.1 sat/vByte == 25 sat/kwu`).
  const factory NetworkFee.relativeSatPerKwu(int satPerKwu) = RelativeFee;

  /// Build a [RelativeFee] from a sat/vByte value as typed by the user
  /// or returned by the mempool API.
  ///
  /// Returns [RelativeFee] (not [NetworkFee]) so callers don't need to cast
  /// — sealed-union factories would static-type to the parent.
  ///
  /// The conversion rounds to the nearest sat/kwu: precision loss is bounded
  /// by 0.5 / 250 ≈ 0.002 sat/vByte, well below any meaningful UX threshold.
  static RelativeFee relativeFromSatPerVbyte(double satPerVbyte) =>
      RelativeFee((satPerVbyte * 250).round());

  /// Build a [RelativeFee] from an absolute fee target plus an estimated
  /// tx vsize.
  ///
  /// Used when the user enters an absolute amount on a network whose SDK
  /// only accepts a rate (Liquid send, RBF bump). The dance costs at most
  /// ±1 sat in the final fee (BDK/LWK may rebuild with a slightly different
  /// vsize than the estimate) — that's the structural cost of the SDK's
  /// rate-only contract, not something we can eliminate.
  static RelativeFee relativeFromAbsoluteAndVsize({
    required int absoluteSats,
    required int vsize,
  }) {
    assert(vsize > 0, 'vsize must be positive');
    // sat/kwu = (absoluteSats / vsize) * 250
    //        = (absoluteSats * 250) / vsize, rounded to nearest via integer
    // math. The `vsize ~/ 2` bias term truncates on odd vsize, so an exact
    // half rounds down there; the resulting bias is under 1 sat/kwu
    // (< 0.004 sat/vByte), well inside the ±1 sat tolerance noted above.
    return RelativeFee((absoluteSats * 250 + vsize ~/ 2) ~/ vsize);
  }

  bool get isAbsolute => this is AbsoluteFee;
  bool get isRelative => this is RelativeFee;

  /// Numeric value kept for display-layer compatibility.
  ///
  /// - [AbsoluteFee] returns its amount in sats (`int`).
  /// - [RelativeFee] returns its rate in sat/vByte (`double`).
  num get value => switch (this) {
    AbsoluteFee(:final sats) => sats,
    RelativeFee(:final satPerKwu) => satPerKwu / 250.0,
  };

  /// Convert this fee to its absolute form given a tx vsize (in vbytes).
  ///
  /// Identity for [AbsoluteFee]; computes `(satPerKwu * vsize) / 250`
  /// rounded half-up for [RelativeFee].
  NetworkFee toAbsolute(int vsize) => switch (this) {
    AbsoluteFee() => this,
    RelativeFee(:final satPerKwu) => NetworkFee.absolute(
      (satPerKwu * vsize + 125) ~/ 250,
    ),
  };
}

/// UI-facing accessors on [RelativeFee] — these are display conversions only,
/// never round-tripped back into storage.
extension RelativeFeeDisplay on RelativeFee {
  /// Display in sat/vByte (the unit users type).
  double get satPerVbyte => satPerKwu / 250.0;

  /// Display in sat per 1000 vBytes — LWK's preferred unit.
  /// 1 kvB = 4 kwu, so 1 sat/kwu = 4 sat/kvByte.
  double get satPerKvbyte => satPerKwu * 4.0;
}

/// Minimum-relay policy for transaction fees — single source of truth used
/// by the cubit/bloc commit gates, the custom-fee widget's "below floor"
/// banner, and the Slow-preset floor in [MempoolFeesMapper]. The value
/// matches both Bitcoin Core's lowest sensible relay policy and Liquid's
/// network minrelayfee, so the same constant is correct on both chains.
extension NetworkFeeRelayPolicy on NetworkFee {
  /// 0.1 sat/vByte = 25 sat/kwu, exact.
  static const double minRelaySatPerVbyte = 0.1;
  static const int minRelaySatPerKwu = 25;

  /// True when this fee is at or above the relay floor. The floor defaults
  /// to the static [minRelaySatPerKwu] (0.1 sat/vByte) but callers SHOULD
  /// pass [floorSatPerKwu] from the live mempool `minimumFee`
  /// ([FeeOptions.minRelay]) so the gate tracks the network's current
  /// minimum during congestion — never below the static 0.1 safety floor,
  /// since [MempoolFeesMapper] takes `max(minimumFee, 0.1)`.
  ///
  /// Absolute fees need a [txSize] to express as a rate; [txSize] ≤ 0 →
  /// false (the caller is in a transient pre-build state and shouldn't be
  /// allowed to commit yet). The absolute comparison is done in sat/kwu
  /// space (`sats * 250 ≥ floor * txSize`) to avoid float rounding.
  bool aboveMinRelay({int? txSize, int? floorSatPerKwu}) {
    final floor = floorSatPerKwu ?? minRelaySatPerKwu;
    return switch (this) {
      RelativeFee(:final satPerKwu) => satPerKwu >= floor,
      AbsoluteFee(:final sats) =>
        txSize != null &&
            txSize > 0 &&
            (BigInt.from(sats) * BigInt.from(250)) >=
                (BigInt.from(floor) * BigInt.from(txSize)),
    };
  }
}

@freezed
abstract class FeeOptions with _$FeeOptions {
  const factory FeeOptions({
    required NetworkFee fastest,
    required NetworkFee economic,
    required NetworkFee slow,

    /// The network's current relay floor as a rate — mempool's `minimumFee`
    /// clamped up to the static 0.1 sat/vByte safety floor. Validation gates
    /// (custom-fee field, commit gates) reject anything below this so the app
    /// never builds a tx the network won't relay, even during congestion when
    /// `minimumFee` rises above 0.1. A pure rate, never converted to absolute.
    required RelativeFee minRelay,
  }) = _FeeOptions;
  const FeeOptions._();

  FeeOptions toAbsolute(int vsize) => FeeOptions(
    fastest: fastest.toAbsolute(vsize),
    economic: economic.toAbsolute(vsize),
    slow: slow.toAbsolute(vsize),
    minRelay: minRelay,
  );

  FeeOptions toRelative(int vsize) {
    NetworkFee asRelative(NetworkFee fee) => switch (fee) {
      AbsoluteFee(:final sats) => NetworkFee.relativeFromAbsoluteAndVsize(
        absoluteSats: sats,
        vsize: vsize,
      ),
      RelativeFee() => fee,
    };
    return FeeOptions(
      fastest: asRelative(fastest),
      economic: asRelative(economic),
      slow: asRelative(slow),
      minRelay: minRelay,
    );
  }
}

enum FeeSelection { fastest, economic, slow, custom }

extension FeeSelectionName on FeeSelection {
  String title() {
    switch (this) {
      case FeeSelection.fastest:
        return 'Fastest';
      case FeeSelection.economic:
        return 'Economic';
      case FeeSelection.slow:
        return 'Slow';
      case FeeSelection.custom:
        return 'Custom Fee';
    }
  }

  static FeeSelection fromString(String value) {
    switch (value) {
      case 'Fastest':
        return FeeSelection.fastest;
      case 'Economic':
        return FeeSelection.economic;
      case 'Slow':
        return FeeSelection.slow;
      case 'Custom Fee':
        return FeeSelection.custom;
      default:
        throw Exception('Unknown fee selection: $value');
    }
  }
}
