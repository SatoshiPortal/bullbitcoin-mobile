import 'package:swaps/src/util.dart' show SwapsException;
import 'package:primitives/primitives.dart';
import 'package:swaps/src/data/models/boltz_network.dart';
import 'package:swaps/src/domain/entities/derived_swap_master_key.dart';
import 'package:rust_bindings/boltz.dart' as boltz;

/// The dedicated swap master key (the "swap mnemonic"), derived by the app's
/// secrets layer and persisted per network. Boltz swap constructors derive
/// their per-swap keys from this key + an index.
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
    'regtest' => BoltzNetwork.regtest,
    _ => throw const FormatException('Unknown swap key network'),
  };

  factory SwapMasterKeyModel.fromDerived(DerivedSwapMasterKey key) {
    return SwapMasterKeyModel(
      xprv: key.xprv,
      xpub: key.xpub,
      network: key.environment.name,
      mnemonic: key.mnemonic,
      fingerprint: key.fingerprint,
    );
  }

  factory SwapMasterKeyModel.fromBoltz(boltz.SwapMasterKey boltzKey) {
    return SwapMasterKeyModel(
      xprv: boltzKey.xprv,
      xpub: boltzKey.xpub,
      network: boltzKey.network.name,
      mnemonic: boltzKey.mnemonic,
      fingerprint: boltzKey.fingerprint,
    );
  }

  boltz.SwapMasterKey toBoltz() {
    return boltz.SwapMasterKey(
      xprv: xprv,
      xpub: xpub,
      network: switch (boltzNetwork) {
        BoltzNetwork.mainnet => boltz.Network.mainnet,
        BoltzNetwork.testnet => boltz.Network.testnet,
        BoltzNetwork.regtest => boltz.Network.regtest,
      },
      mnemonic: mnemonic,
      fingerprint: fingerprint,
    );
  }

  SwapMasterKeyModel requireEnvironment(NetworkEnv environment) {
    if (boltzNetwork.environment != environment) {
      throw SwapsException('Swap key network does not match its engine');
    }
    return this;
  }

  factory SwapMasterKeyModel.fromJson(Map<String, dynamic> json) {
    if (json case {
      'xprv': final String privateKey,
      'xpub': final String publicKey,
      'network': final String network,
      'mnemonic': final String mnemonic,
      'fingerprint': final String fingerprint,
    }) {
      return SwapMasterKeyModel(
        xprv: privateKey,
        xpub: publicKey,
        network: network,
        mnemonic: mnemonic,
        fingerprint: fingerprint,
      );
    }
    throw const FormatException('Unreadable swap key record');
  }

  Map<String, dynamic> toJson() => {
    'xprv': xprv,
    'xpub': xpub,
    'network': network,
    'mnemonic': mnemonic,
    'fingerprint': fingerprint,
  };
}
