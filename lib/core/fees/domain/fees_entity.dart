import 'package:freezed_annotation/freezed_annotation.dart';

part 'fees_entity.freezed.dart';

@freezed
class MinerFee with _$MinerFee {
  const MinerFee._();

  const factory MinerFee.absolute(int value) = AbsoluteFee;
  const factory MinerFee.relative(double value) = RelativeFee;

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
    required MinerFee fastest,
    required MinerFee economic,
    required MinerFee slow,
  }) = _FeeOptions;
  const FeeOptions._();

  FeeOptions toAbsolute(int size) {
    return FeeOptions(
      fastest: fastest.when(
        absolute: (value) => MinerFee.absolute(value),
        relative: (value) => MinerFee.absolute((value * size).round()),
      ),
      economic: economic.when(
        absolute: (value) => MinerFee.absolute(value),
        relative: (value) => MinerFee.absolute((value * size).round()),
      ),
      slow: slow.when(
        absolute: (value) => MinerFee.absolute(value),
        relative: (value) => MinerFee.absolute((value * size).round()),
      ),
    );
  }

  FeeOptions toRelative(int size) {
    return FeeOptions(
      fastest: fastest.when(
        absolute: (value) => MinerFee.relative(value / size),
        relative: (value) => MinerFee.relative(value),
      ),
      economic: economic.when(
        absolute: (value) => MinerFee.relative(value / size),
        relative: (value) => MinerFee.relative(value),
      ),
      slow: slow.when(
        absolute: (value) => MinerFee.relative(value / size),
        relative: (value) => MinerFee.relative(value),
      ),
    );
  }
}
