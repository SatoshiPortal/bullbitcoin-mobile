import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter/widgets.dart';

/// What the shared send screens read off the wallet a payment is sent from.
///
/// Two things can be sent from and they are not the same shape: a bitcoin or
/// liquid [Wallet] has descriptors and a signer, and a Silent Payments wallet
/// has neither. Rather than hand the screens a `Wallet` with invented
/// descriptors and a made-up fingerprint, each case answers for itself and the
/// fields silent payments genuinely does not have come back null.
sealed class SendWalletView {
  const SendWalletView();

  String get id;
  Network get network;
  BigInt get balanceSat;
  ScriptType? get scriptType;
  SignerDeviceEntity? get signerDevice;
  String? get derivationPath;
  bool get signsLocally;
  bool get signsRemotely;

  /// The wallet's own label, when it has one. Not localized: [displayLabel]
  /// is what the screens show.
  String? get label;

  String displayLabel(BuildContext context);

  bool get isLiquid;

  /// Signing happens on a device. Silent payments never signs at all.
  bool get isHardwareWallet => signerDevice != null;
}

/// A real bitcoin or liquid wallet. Keeps the entity so the paths that sign,
/// select coins or quote a swap can still reach it.
final class SendWalletBitcoin extends SendWalletView {
  final Wallet wallet;

  const SendWalletBitcoin(this.wallet);

  @override
  String get id => wallet.id;
  @override
  Network get network => wallet.network;
  @override
  BigInt get balanceSat => wallet.balanceSat;
  @override
  ScriptType? get scriptType => wallet.scriptType;
  @override
  SignerDeviceEntity? get signerDevice => wallet.signerDevice;
  @override
  String? get derivationPath => wallet.derivationPath;
  @override
  bool get signsLocally => wallet.signsLocally;
  @override
  bool get signsRemotely => wallet.signsRemotely;
  @override
  String? get label => wallet.label;
  @override
  bool get isLiquid => wallet.isLiquid;

  @override
  String displayLabel(BuildContext context) => wallet.displayLabel(context);

  @override
  bool operator ==(Object other) =>
      other is SendWalletBitcoin && other.wallet == wallet;

  @override
  int get hashCode => wallet.hashCode;
}

/// The Silent Payments wallet. It has no descriptors, no signer and no
/// derivation path, and nothing is ever signed against it: the spend is built
/// and broadcast on the Rust side. Those fields are absent, not invented.
final class SendWalletSp extends SendWalletView {
  @override
  final String label;
  @override
  final Network network;
  @override
  final BigInt balanceSat;

  const SendWalletSp({
    required this.label,
    required this.network,
    required this.balanceSat,
  });

  @override
  String get id => 'sp';
  @override
  ScriptType? get scriptType => null;
  @override
  SignerDeviceEntity? get signerDevice => null;
  @override
  String? get derivationPath => null;
  @override
  bool get signsLocally => false;
  @override
  bool get signsRemotely => false;
  @override
  bool get isLiquid => false;

  @override
  String displayLabel(BuildContext context) => label;

  @override
  bool operator ==(Object other) =>
      other is SendWalletSp &&
      other.label == label &&
      other.network == network &&
      other.balanceSat == balanceSat;

  @override
  int get hashCode => Object.hash(label, network, balanceSat);
}
