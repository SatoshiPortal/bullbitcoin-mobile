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

enum FeeSelection { fastest, economic, slow }

extension FeeSelectionName on FeeSelection {
  String title() {
    switch (this) {
      case FeeSelection.fastest:
        return 'Fastest';
      case FeeSelection.economic:
        return 'Economic';
      case FeeSelection.slow:
        return 'Slow';
    }
  }
}
