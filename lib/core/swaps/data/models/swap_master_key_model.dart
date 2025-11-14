import 'package:bb_mobile/core/swaps/domain/entity/boltz_network.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_master_key.dart'
    as domain;
import 'package:boltz/boltz.dart' as boltz;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_master_key_model.freezed.dart';
part 'swap_master_key_model.g.dart';

@freezed
sealed class SwapMasterKeyModel with _$SwapMasterKeyModel {
  const factory SwapMasterKeyModel({
    required String xprv,
    required String xpub,
    required String network,
    required String mnemonic,
    required String fingerprint,
  }) = _SwapMasterKeyModel;

  const SwapMasterKeyModel._();

  factory SwapMasterKeyModel.fromJson(Map<String, dynamic> json) =>
      _$SwapMasterKeyModelFromJson(json);

  factory SwapMasterKeyModel.fromEntity(domain.SwapMasterKey entity) {
    return SwapMasterKeyModel(
      xprv: entity.xprv,
      xpub: entity.xpub,
      network: entity.network.value,
      mnemonic: entity.mnemonic,
      fingerprint: entity.fingerprint,
    );
  }

  domain.SwapMasterKey toEntity() {
    final boltzNetwork = switch (network) {
      'testnet' => BoltzNetwork.testnet,
      'mainnet' => BoltzNetwork.mainnet,
      _ => throw Exception('Unknown BoltzNetwork value: $network'),
    };

    return domain.SwapMasterKey(
      xprv: xprv,
      xpub: xpub,
      network: boltzNetwork,
      mnemonic: mnemonic,
      fingerprint: fingerprint,
    );
  }

  factory SwapMasterKeyModel.fromBoltz(boltz.SwapMasterKey boltzKey) {
    final networkString =
        boltzKey.network == boltz.Network.testnet ? 'testnet' : 'mainnet';

    return SwapMasterKeyModel(
      xprv: boltzKey.xprv,
      xpub: boltzKey.xpub,
      network: networkString,
      mnemonic: boltzKey.mnemonic,
      fingerprint: boltzKey.fingerprint,
    );
  }

  boltz.SwapMasterKey toBoltz() {
    final boltzNetwork =
        network == 'testnet' ? boltz.Network.testnet : boltz.Network.mainnet;

    return boltz.SwapMasterKey(
      xprv: xprv,
      xpub: xpub,
      network: boltzNetwork,
      mnemonic: mnemonic,
      fingerprint: fingerprint,
    );
  }
}
