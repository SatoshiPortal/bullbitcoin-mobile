import 'package:fees/fees.dart';
import 'package:meta/meta.dart';

import 'spend_options_event.dart';
import 'spend_options_state.dart';

@immutable
sealed class SpendOptionsEffect {
  const SpendOptionsEffect();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is SpendOptionsEffect &&
      other.runtimeType == runtimeType &&
      spendPropsEqual(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));

  @override
  String toString() => '$runtimeType(${_props.join(', ')})';
}

/// Read the fee estimates; answer [SpendFeesLoaded] / [SpendFeesFailed].
final class SpendLoadFees extends SpendOptionsEffect {
  final int attempt;

  const SpendLoadFees(this.attempt);

  @override
  List<Object?> get _props => [attempt];
}

/// List [walletId]'s coins; answer [SpendCoinsRead].
final class SpendLoadCoins extends SpendOptionsEffect {
  final String walletId;

  const SpendLoadCoins(this.walletId);

  @override
  List<Object?> get _props => [walletId];
}

/// Price the presets; answer [SpendPresetsPreviewed] for [epoch].
final class SpendPreviewPresets extends SpendOptionsEffect {
  final int epoch;
  final FeeOptions fees;
  final SpendPreviewShape shape;

  const SpendPreviewPresets(this.epoch, this.fees, this.shape);

  @override
  List<Object?> get _props => [epoch, fees, shape];
}

/// Price [fee]; answer [SpendCustomPreviewed] for [epoch].
final class SpendPreviewCustom extends SpendOptionsEffect {
  final int epoch;
  final NetworkFee fee;
  final SpendPreviewShape shape;

  const SpendPreviewCustom(this.epoch, this.fee, this.shape);

  @override
  List<Object?> get _props => [epoch, fee, shape];
}
