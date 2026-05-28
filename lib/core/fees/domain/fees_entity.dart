import 'package:bb_mobile/core/utils/amount_conversions.dart';
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
    //        = (absoluteSats * 250) / vsize, rounded half-up via integer math.
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
    RelativeFee(:final satPerKwu) =>
      NetworkFee.absolute((satPerKwu * vsize + 125) ~/ 250),
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

@freezed
abstract class FeeOptions with _$FeeOptions {
  const factory FeeOptions({
    required NetworkFee fastest,
    required NetworkFee economic,
    required NetworkFee slow,
  }) = _FeeOptions;
  const FeeOptions._();

  FeeOptions toAbsolute(int vsize) => FeeOptions(
    fastest: fastest.toAbsolute(vsize),
    economic: economic.toAbsolute(vsize),
    slow: slow.toAbsolute(vsize),
  );

  FeeOptions toRelative(int vsize) {
    NetworkFee asRelative(NetworkFee fee) => switch (fee) {
      AbsoluteFee(:final sats) =>
        NetworkFee.relativeFromAbsoluteAndVsize(
          absoluteSats: sats,
          vsize: vsize,
        ),
      RelativeFee() => fee,
    };
    return FeeOptions(
      fastest: asRelative(fastest),
      economic: asRelative(economic),
      slow: asRelative(slow),
    );
  }
}

extension FeeOptionsDisplay on FeeOptions {
  List<(String, String, String)> display(
    int txSize,
    double exchangeRate,
    String currencySymbol,
  ) {
    // Predictions only — preset tiles never have a real PSBT to read from
    // (no commit happened yet). Use integer math via NetworkFee.toAbsolute
    // so the line doesn't render IEEE-noisy doubles like 208.0 or
    // 14.100000000000001. BDK may still pay 1-3 sats more at sub-1
    // sat/vByte rates due to ceil + dust absorption — that's documented
    // BDK behaviour we can't predict without building a real tx.
    final fastestAbsSats = fastest.toAbsolute(txSize).value.toInt();
    final economicAbsSats = economic.toAbsolute(txSize).value.toInt();
    final slowAbsSats = slow.toAbsolute(txSize).value.toInt();
    final fastestFiatEq = ConvertAmount.satsToFiat(
      fastestAbsSats,
      exchangeRate,
    );
    final economicFiatEq = ConvertAmount.satsToFiat(
      economicAbsSats,
      exchangeRate,
    );
    final slowFiatEq = ConvertAmount.satsToFiat(slowAbsSats, exchangeRate);
    // `~` not `=` between rate and sat-count: the sat-count is a
    // prediction (rate × vsize, integer-rounded). BDK pays 1-3 sats more
    // at sub-1 sat/vByte due to ceil + sub-dust change absorption.
    return [
      (
        'Fastest',
        'Estimated delivery ~ 10 minutes',
        '${fastest.value} sats/byte ~ $fastestAbsSats sats (~ $fastestFiatEq) $currencySymbol',
      ),
      (
        'Economic',
        'Estimated delivery ~ 30 minutes',
        '${economic.value} sats/byte ~ $economicAbsSats sats (~ $economicFiatEq) $currencySymbol',
      ),
      (
        'Slow',
        'Estimated delivery ~ few hours',
        '${slow.value} sats/byte ~ $slowAbsSats sats (~ $slowFiatEq) $currencySymbol',
      ),
    ];
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
