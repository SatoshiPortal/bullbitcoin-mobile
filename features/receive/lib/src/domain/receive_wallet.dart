import 'package:primitives/primitives.dart';
import 'package:signers/signers.dart';

/// Public metadata needed when entering Receive from a wallet.
final class ReceiveWallet {
  final String id;
  final Network network;
  final bool signsLocally;
  final bool isDefault;
  final String? label;
  final ScriptType scriptType;
  final String? derivationPath;
  final SignerDevice? signerDevice;
  final BigInt? balanceSat;
  final BigInt? confirmedBalanceSat;

  const ReceiveWallet({
    required this.id,
    required this.network,
    required this.signsLocally,
    required this.scriptType,
    this.isDefault = false,
    this.label,
    this.derivationPath,
    this.signerDevice,
    this.balanceSat,
    this.confirmedBalanceSat,
  });

  bool get isBitcoin => network is BitcoinNetwork;
  bool get isLiquid => network is LiquidNetwork;

  BitcoinNetwork get bitcoinNetwork => switch (network) {
    final BitcoinNetwork bitcoin => bitcoin,
    _ => throw StateError('Bitcoin receive requires a Bitcoin wallet'),
  };
}
