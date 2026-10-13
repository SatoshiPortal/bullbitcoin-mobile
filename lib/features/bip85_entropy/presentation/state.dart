import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

/// Holds BIP85 children for display, so its `toString` names none of them:
/// an interpolated state must not put key material in a log.
@Freezed(toStringOverride: false)
sealed class Bip85EntropyState with _$Bip85EntropyState {
  const factory Bip85EntropyState({
    Bip85Failure? failure,
    @Default([])
    List<({Bip85DerivationEntity derivation, String entropy})> derivations,
    @Default(false) bool isLoading,
  }) = _Bip85EntropyState;

  const Bip85EntropyState._();

  @override
  String toString() =>
      'Bip85EntropyState(derivations: ${derivations.length}, '
      'isLoading: $isLoading, failure: ${failure?.runtimeType})';
}
