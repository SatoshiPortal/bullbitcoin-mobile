import 'package:primitives/primitives.dart';
import 'package:signers/signers.dart' show SignerDevice;

/// The public description of one wallet, as shown in its settings.
final class WalletDetails {
  final String id;
  final String? label;
  final bool isDefault;
  final Network network;
  final ScriptType scriptType;

  /// The key origin fingerprint, verbatim from the registration.
  final String masterFingerprint;
  final String xpub;
  final String externalDescriptor;
  final SignerEntity signer;

  /// The signer device recorded at import, if any.
  final SignerDevice? signerDevice;

  const WalletDetails({
    required this.id,
    required this.label,
    required this.isDefault,
    required this.network,
    required this.scriptType,
    required this.masterFingerprint,
    required this.xpub,
    required this.externalDescriptor,
    required this.signer,
    required this.signerDevice,
  });

  bool get isLiquid => network is LiquidNetwork;

  String get addressType => isLiquid
      ? 'Confidential Segwit'
      : switch (scriptType) {
          ScriptType.bip84 => 'Native Segwit',
          ScriptType.bip49 => 'Nested Segwit',
          ScriptType.bip44 => 'Legacy',
        };

  String get networkName => switch (network) {
    BitcoinNetwork.mainnet => 'Bitcoin Network',
    BitcoinNetwork.testnet => 'Bitcoin Testnet',
    BitcoinNetwork.signet => 'Bitcoin Signet',
    BitcoinNetwork.regtest => 'Bitcoin Regtest',
    LiquidNetwork.mainnet => 'Liquid Network',
    LiquidNetwork.testnet => 'Liquid Testnet',
    LiquidNetwork.regtest => 'Liquid Regtest',
  };

  /// The key origin path of the external descriptor, or the account path of
  /// the script type when the descriptor carries no origin.
  String get derivationPath {
    final fallback = "m/${scriptType.purpose}'/${network.coinType}'/0'";
    final start = externalDescriptor.indexOf('[');
    final end = externalDescriptor.indexOf(']');
    if (start == -1 || end == -1 || start >= end) return fallback;
    final parts = externalDescriptor.substring(start + 1, end).split('/');
    if (parts.length < 2) return fallback;
    return 'm/${parts.skip(1).join('/')}';
  }
}
