import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/features/bip85_entropy/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class Bip85EntropyState with _$Bip85EntropyState {
  const factory Bip85EntropyState({
    Bip85EntropyError? error,
    @Default([]) List<Bip85DerivationEntity> derivations,
    @Default('') String xprvBase58,
  }) = _Bip85EntropyState;
}
