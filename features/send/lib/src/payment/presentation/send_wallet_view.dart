import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart' show Network, ScriptType;
import 'package:signers/signers.dart';
import 'package:flutter/widgets.dart';

import '../domain/send_source.dart';

import 'package:send/src/send_localizations.dart';

/// The selected account or Silent Payments wallet shown on the send screens.
///
/// Silent Payments does not expose a signer, derivation path or script type.
sealed class SendWalletView {
  const SendWalletView();

  String get id;
  Network get network;
  BigInt? get balanceSat;
  ScriptType? get scriptType;
  SignerDevice? get signerDevice;
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
  final SendSource wallet;

  const SendWalletBitcoin(this.wallet);

  @override
  String get id => wallet.id;
  @override
  Network get network => wallet.network;
  @override
  BigInt? get balanceSat => wallet.balanceSat;
  @override
  ScriptType? get scriptType => wallet.scriptType;
  @override
  SignerDevice? get signerDevice => wallet.signerDevice;
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

extension SendSourcePresentation on SendSource {
  String displayLabel(BuildContext context) => switch ((isDefault, isLiquid)) {
    (true, true) => context.loc.globalDefaultLiquidWalletLabel,
    (true, false) => context.loc.globalDefaultBitcoinWalletLabel,
    (false, _) => label ?? id.replaceFirst(RegExp(r':regtest$'), ''),
  };

  String typeLabel(BuildContext context) {
    if (signsRemotely) return context.loc.walletTypeWatchSigner;
    if (isWatchOnly) return context.loc.walletTypeWatchOnly;
    return isBitcoin
        ? context.loc.walletTypeBitcoinNetwork
        : context.loc.walletTypeLiquidAndLightning;
  }

  Color tagColor(BuildContext context) {
    final colors = context.appColors;
    if (isWatchOnly || signsRemotely) return colors.secondary;
    return isLiquid ? colors.tertiary : colors.onTertiary;
  }
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
  SignerDevice? get signerDevice => null;
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
