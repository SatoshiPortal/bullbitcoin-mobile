import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

enum WalletSigner { local, remote, none }

/// A visible wallet's validated inventory metadata, without its descriptors.
final class WalletRegistration {
  final String id;
  final Network network;
  final ScriptType scriptType;
  final WalletSigner signer;

  /// Validated public key origin, for every signer type.
  final Fingerprint? masterFingerprint;

  /// The expected local seed reference, not proof of seed availability or authority.
  final Fingerprint? secretFingerprint;

  /// The path in the external descriptor's key origin, if available.
  final String? derivationPath;
  final String? label;
  final DateTime? birthday;
  final bool isDefault;

  @internal
  const WalletRegistration({
    required this.id,
    required this.network,
    required this.scriptType,
    required this.signer,
    required this.masterFingerprint,
    required this.secretFingerprint,
    required this.derivationPath,
    required this.label,
    required this.birthday,
    required this.isDefault,
  });
}

/// Readable wallets on one concrete network, in stable wallet ID order.
final class WalletSelection {
  final List<WalletRegistration> wallets;

  /// Whether every visible wallet on the requested network was readable.
  final bool isComplete;

  /// All wallets explicitly marked as default, including any legacy conflict.
  final List<WalletRegistration> defaults;

  @internal
  WalletSelection(List<WalletRegistration> wallets, {required this.isComplete})
    : wallets = List.unmodifiable(wallets),
      defaults = List.unmodifiable(wallets.where((wallet) => wallet.isDefault));

  /// The sole readable default; null if none or several are marked.
  WalletRegistration? get defaultWallet =>
      defaults.length == 1 ? defaults.single : null;
}
