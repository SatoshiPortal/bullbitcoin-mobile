import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/features/electrum_settings/domain/electrum_environment.dart';

enum ElectrumServerNetwork {
  bitcoinMainnet,
  bitcoinTestnet,
  liquidMainnet,
  liquidTestnet,
  bitcoinRegtest,
  liquidRegtest;

  static ElectrumServerNetwork fromEnvironment({
    required ElectrumEnvironment environment,
    required bool isLiquid,
  }) => switch ((environment, isLiquid)) {
    (ElectrumEnvironment.mainnet, false) => bitcoinMainnet,
    (ElectrumEnvironment.mainnet, true) => liquidMainnet,
    (ElectrumEnvironment.testnet, false) => bitcoinTestnet,
    (ElectrumEnvironment.testnet, true) => liquidTestnet,
    (ElectrumEnvironment.regtest, false) => bitcoinRegtest,
    (ElectrumEnvironment.regtest, true) => liquidRegtest,
  };

  static ElectrumServerNetwork fromNetworkEnv(
    NetworkEnv environment, {
    required bool isLiquid,
  }) => fromEnvironment(
    environment: switch (environment) {
      NetworkEnv.mainnet => ElectrumEnvironment.mainnet,
      NetworkEnv.testnet => ElectrumEnvironment.testnet,
      NetworkEnv.regtest => ElectrumEnvironment.regtest,
      NetworkEnv.signet => throw const ElectrumUnsupportedNetworkException(),
    },
    isLiquid: isLiquid,
  );

  static ElectrumServerNetwork fromStorageName(String value) => switch (value) {
    'bitcoinMainnet' => bitcoinMainnet,
    'bitcoinTestnet' => bitcoinTestnet,
    'liquidMainnet' => liquidMainnet,
    'liquidTestnet' => liquidTestnet,
    'bitcoinRegtest' => bitcoinRegtest,
    'liquidRegtest' => liquidRegtest,
    _ => throw const FormatException('Unknown Electrum network'),
  };
}

extension ElectrumServerNetworkX on ElectrumServerNetwork {
  String get storageName => switch (this) {
    ElectrumServerNetwork.bitcoinMainnet => 'bitcoinMainnet',
    ElectrumServerNetwork.bitcoinTestnet => 'bitcoinTestnet',
    ElectrumServerNetwork.liquidMainnet => 'liquidMainnet',
    ElectrumServerNetwork.liquidTestnet => 'liquidTestnet',
    ElectrumServerNetwork.bitcoinRegtest => 'bitcoinRegtest',
    ElectrumServerNetwork.liquidRegtest => 'liquidRegtest',
  };

  ElectrumEnvironment get environment => switch (this) {
    ElectrumServerNetwork.bitcoinMainnet ||
    ElectrumServerNetwork.liquidMainnet => ElectrumEnvironment.mainnet,
    ElectrumServerNetwork.bitcoinTestnet ||
    ElectrumServerNetwork.liquidTestnet => ElectrumEnvironment.testnet,
    ElectrumServerNetwork.bitcoinRegtest ||
    ElectrumServerNetwork.liquidRegtest => ElectrumEnvironment.regtest,
  };

  bool get isLiquid => switch (this) {
    ElectrumServerNetwork.bitcoinMainnet ||
    ElectrumServerNetwork.bitcoinTestnet ||
    ElectrumServerNetwork.bitcoinRegtest => false,
    ElectrumServerNetwork.liquidMainnet ||
    ElectrumServerNetwork.liquidTestnet ||
    ElectrumServerNetwork.liquidRegtest => true,
  };
}

/// A concrete environment cannot be represented by the supported server catalog.
final class ElectrumUnsupportedNetworkException implements Exception {
  const ElectrumUnsupportedNetworkException();
}
