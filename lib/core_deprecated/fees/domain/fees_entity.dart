import 'package:bb_mobile/core_deprecated/utils/amount_conversions.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fees_entity.freezed.dart';

@freezed
sealed class NetworkFee with _$NetworkFee {
  const NetworkFee._();

  const factory NetworkFee.absolute(int value) = AbsoluteFee;
  const factory NetworkFee.relative(double value) = RelativeFee;

  bool get isAbsolute => this is AbsoluteFee;
  bool get isRelative => this is RelativeFee;

  @override
  num get value => switch (this) {
    AbsoluteFee(:final value) => value,
    RelativeFee(:final value) => value,
  };

  // add to absolute fee
  NetworkFee toAbsolute(int size) {
    return switch (this) {
      AbsoluteFee(:final value) => NetworkFee.absolute(value),
      RelativeFee(:final value) => NetworkFee.absolute((value * size).round()),
    };
  }
}

@freezed
abstract class FeeOptions with _$FeeOptions {
  const factory FeeOptions({
    required NetworkFee fastest,
    required NetworkFee economic,
    required NetworkFee slow,
  }) = _FeeOptions;
  const FeeOptions._();

  FeeOptions toAbsolute(int size) {
    return FeeOptions(
      fastest: switch (fastest) {
        AbsoluteFee(:final value) => NetworkFee.absolute(value),
        RelativeFee(:final value) => NetworkFee.absolute(
          (value * size).round(),
        ),
      },
      economic: switch (economic) {
        AbsoluteFee(:final value) => NetworkFee.absolute(value),
        RelativeFee(:final value) => NetworkFee.absolute(
          (value * size).round(),
        ),
      },
      slow: switch (slow) {
        AbsoluteFee(:final value) => NetworkFee.absolute(value),
        RelativeFee(:final value) => NetworkFee.absolute(
          (value * size).round(),
        ),
      },
    );
  }

  FeeOptions toRelative(int size) {
    return FeeOptions(
      fastest: switch (fastest) {
        AbsoluteFee(:final value) => NetworkFee.relative(value / size),
        RelativeFee(:final value) => NetworkFee.relative(value),
      },
      economic: switch (economic) {
        AbsoluteFee(:final value) => NetworkFee.relative(value / size),
        RelativeFee(:final value) => NetworkFee.relative(value),
      },
      slow: switch (slow) {
        AbsoluteFee(:final value) => NetworkFee.relative(value / size),
        RelativeFee(:final value) => NetworkFee.relative(value),
      },
    );
  }
}

extension FeeOptionsDisplay on FeeOptions {
  List<(String, String, String)> display(
    int txSize,
    double exchangeRate,
    String currencySymbol,
  ) {
    //title
    // subtitle - Estimated delivery ～ 10 minutes
    // subtitle2 - 10 sats/byte = 2,083 sats ($1,37) fee
    final fastestAbsValue = fastest.value * txSize;
    final economicAbsValue = economic.value * txSize;
    final slowAbsValue = slow.value * txSize;
    final fastestFiatEq = ConvertAmount.satsToFiat(
      fastestAbsValue.toInt(),
      exchangeRate,
    );
    final economicFiatEq = ConvertAmount.satsToFiat(
      economicAbsValue.toInt(),
      exchangeRate,
    );
    final slowFiatEq = ConvertAmount.satsToFiat(
      slowAbsValue.toInt(),
      exchangeRate,
    );
    return [
      (
        'Fastest',
        'Estimated delivery ~ 10 minutes',
        '${fastest.value} sats/byte = $fastestAbsValue sats (~ $fastestFiatEq) $currencySymbol',
      ),
      (
        'Economic',
        'Estimated delivery ~ 30 minutes',
        '${economic.value} sats/byte = $economicAbsValue sats (~ $economicFiatEq) $currencySymbol',
      ),
      (
        'Slow',
        'Estimated delivery ~ few hours',
        '${slow.value} sats/byte = $slowAbsValue sats (~ $slowFiatEq) $currencySymbol',
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
