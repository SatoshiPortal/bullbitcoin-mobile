import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show WalletKey;

/// Wallet information required to select and fund a transfer.
final class SwapWallet {
  final WalletRegistration registration;
  final BigInt? balanceSat;
  final bool isHardwareWallet;

  const SwapWallet(this.registration, this.balanceSat, this.isHardwareWallet);

  String get id => registration.id;
  String? get label => registration.label;
  Network get network => registration.network;
  bool get isDefault => registration.isDefault;
  bool get isLiquid => network is LiquidNetwork;
  bool get isBitcoin => network is BitcoinNetwork;
  bool get isWatchOnly => registration.signer == WalletSigner.none;
  bool get signsLocally => registration.signer == WalletSigner.local;
  WalletKey get key => WalletKey(id: id, network: network);

  @override
  bool operator ==(Object other) =>
      other is SwapWallet &&
      other.id == id &&
      other.network == network &&
      other.label == label &&
      other.registration.signer == registration.signer &&
      other.isDefault == isDefault &&
      other.balanceSat == balanceSat &&
      other.isHardwareWallet == isHardwareWallet;

  @override
  int get hashCode => Object.hash(
    id,
    network,
    label,
    registration.signer,
    isDefault,
    balanceSat,
    isHardwareWallet,
  );
}
