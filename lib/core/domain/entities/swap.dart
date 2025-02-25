import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap.freezed.dart';

// These types are different than the ones from Boltz to decouple the app from the Boltz API
// In case the Boltz API changes or Boltz starts using new swap technique instead of submarine swaps,
//  or in case we want to add another swaps provider than Boltz,
//  we should be able to do so without changing the domain layer and the rest of the app,
//  only the data layer would need changes.
enum SwapType {
  lightningToBitcoin,
  lightningToLiquid,
  liquidToLightning,
  bitcoinToLightning,
  liquidToBitcoin,
  bitcoinToLiquid,
}

// TODO: add/change to statusses that make sense for the application (so not just the same Boltz swap states, unless it is a status we need in the app to manage or show)
enum SwapStatus {
  pending,
  completed,
  failed,
}

@freezed
class Swap with _$Swap {
  const factory Swap({
    required String id,
    required SwapType type,
    required SwapStatus status,
    required Environment environment,
  }) = _Swap;
  const Swap._();
}
