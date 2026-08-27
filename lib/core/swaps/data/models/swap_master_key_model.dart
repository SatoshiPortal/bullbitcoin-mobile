import 'package:bb_mobile/core/swaps/domain/entity/boltz_network.dart';
import 'package:bull_sdk/boltz.dart' as boltz;

/// The dedicated swap master key (the "swap mnemonic"), derived from a wallet
/// mnemonic and persisted per network. Boltz swap constructors derive their
/// per-swap keys from this key + an index.
class SwapMasterKeyModel {
  final String xprv;
  final String xpub;
  final String network;
  final String mnemonic;
  final String fingerprint;

  const SwapMasterKeyModel({
    required this.xprv,
    required this.xpub,
    required this.network,
    required this.mnemonic,
    required this.fingerprint,
  });

  BoltzNetwork get boltzNetwork => switch (network) {
    'testnet' => BoltzNetwork.testnet,
    'mainnet' => BoltzNetwork.mainnet,
    _ => throw Exception('Unknown BoltzNetwork value: $network'),
  };

  static Future<SwapMasterKeyModel> create({
    required String mnemonic,
    required bool isTestnet,
  }) async {
    final boltzKey = await boltz.SwapMasterKey.create(
      walletMnemonic: mnemonic,
      network: isTestnet ? boltz.Network.testnet : boltz.Network.mainnet,
    );
    return SwapMasterKeyModel.fromBoltz(boltzKey);
  }

  factory SwapMasterKeyModel.fromBoltz(boltz.SwapMasterKey boltzKey) {
    return SwapMasterKeyModel(
      xprv: boltzKey.xprv,
      xpub: boltzKey.xpub,
      network: boltzKey.network == boltz.Network.testnet
          ? 'testnet'
          : 'mainnet',
      mnemonic: boltzKey.mnemonic,
      fingerprint: boltzKey.fingerprint,
    );
  }

  boltz.SwapMasterKey toBoltz() {
    return boltz.SwapMasterKey(
      xprv: xprv,
      xpub: xpub,
      network: network == 'testnet'
          ? boltz.Network.testnet
          : boltz.Network.mainnet,
      mnemonic: mnemonic,
      fingerprint: fingerprint,
    );
  }

  factory SwapMasterKeyModel.fromJson(Map<String, dynamic> json) {
    return SwapMasterKeyModel(
      xprv: json['xprv'] as String,
      xpub: json['xpub'] as String,
      network: json['network'] as String,
      mnemonic: json['mnemonic'] as String,
      fingerprint: json['fingerprint'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'xprv': xprv,
    'xpub': xpub,
    'network': network,
    'mnemonic': mnemonic,
    'fingerprint': fingerprint,
  };
}
