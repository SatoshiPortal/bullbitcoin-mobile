import 'package:bb_mobile/core/swaps/domain/entity/boltz_network.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_master_key.freezed.dart';

@freezed
sealed class SwapMasterKey with _$SwapMasterKey {
  const factory SwapMasterKey({
    required String xprv,
    required String xpub,
    required BoltzNetwork network,
    required String mnemonic,
    required String fingerprint,
  }) = _SwapMasterKey;

  const SwapMasterKey._();
}
