import 'package:freezed_annotation/freezed_annotation.dart';

part 'fees_entity.freezed.dart';

@freezed
class NetworkFee with _$NetworkFee {
  const NetworkFee._();

  const factory NetworkFee.absolute(int value) = AbsoluteFee;
  const factory NetworkFee.relative(double value) = RelativeFee;

  bool get isAbsolute => this is AbsoluteFee;
  bool get isRelative => this is RelativeFee;

  @override
  num get value => when(
        absolute: (value) => value,
        relative: (value) => value,
      );
}

@freezed
class FeeOptions with _$FeeOptions {
  const factory FeeOptions({
    required NetworkFee fastest,
    required NetworkFee economic,
    required NetworkFee slow,
  }) = _FeeOptions;
  const FeeOptions._();

  FeeOptions toAbsolute(int size) {
    return FeeOptions(
      fastest: fastest.when(
        absolute: (value) => NetworkFee.absolute(value),
        relative: (value) => NetworkFee.absolute((value * size).round()),
      ),
      economic: economic.when(
        absolute: (value) => NetworkFee.absolute(value),
        relative: (value) => NetworkFee.absolute((value * size).round()),
      ),
      slow: slow.when(
        absolute: (value) => NetworkFee.absolute(value),
        relative: (value) => NetworkFee.absolute((value * size).round()),
      ),
    );
  }

  FeeOptions toRelative(int size) {
    return FeeOptions(
      fastest: fastest.when(
        absolute: (value) => NetworkFee.relative(value / size),
        relative: (value) => NetworkFee.relative(value),
      ),
      economic: economic.when(
        absolute: (value) => NetworkFee.relative(value / size),
        relative: (value) => NetworkFee.relative(value),
      ),
      slow: slow.when(
        absolute: (value) => NetworkFee.relative(value / size),
        relative: (value) => NetworkFee.relative(value),
      ),
    );
  }
}
