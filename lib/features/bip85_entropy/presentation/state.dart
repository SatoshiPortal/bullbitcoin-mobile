import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class Bip85EntropyState with _$Bip85EntropyState {
  const factory Bip85EntropyState({
    Bip85Failure? failure,
    @Default([])
    List<({Bip85DerivationEntity derivation, String entropy})> derivations,
    @Default(false) bool isLoading,
  }) = _Bip85EntropyState;
}
