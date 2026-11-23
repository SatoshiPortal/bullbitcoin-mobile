import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:signers/signers.dart' show SignerDevice;
import 'package:sync/sync.dart' show WalletKey;

final class SendSource {
  static final _accountOrigin = RegExp(r"\[[a-fA-F0-9]+((?:/\d+h){3})\]");

  final WalletRegistration registration;
  final BigInt? balanceSat;
  final SignerDevice? signerDevice;

  const SendSource(this.registration, this.balanceSat, this.signerDevice);

  String get id => registration.id;
  Network get network => registration.network;
  WalletKey get key => WalletKey(id: id, network: network);
  ScriptType get scriptType => registration.scriptType;
  String? get derivationPath {
    final descriptorPath = registration.derivationPath;
    if (descriptorPath != null) return descriptorPath;
    // Older imports can carry their public key origin only in their wallet ID.
    final accountPath = _accountOrigin.firstMatch(id)?.group(1);
    return accountPath == null ? null : 'm${accountPath.replaceAll('h', "'")}';
  }

  String? get label => registration.label;
  bool get isDefault => registration.isDefault;
  bool get isBitcoin => network is BitcoinNetwork;
  bool get isLiquid => network is LiquidNetwork;
  bool get signsLocally => registration.signer == WalletSigner.local;
  bool get signsRemotely => registration.signer == WalletSigner.remote;
  bool get isWatchOnly => registration.signer == WalletSigner.none;
  bool get isHardwareWallet => signerDevice != null;
  bool get isBitcoinHardwareWallet => isBitcoin && isHardwareWallet;

  // Registration objects are new on every inventory read.
  (
    String,
    Network,
    ScriptType,
    String?,
    String?,
    bool,
    WalletSigner,
    Fingerprint?,
    Fingerprint?,
    DateTime?,
    BigInt?,
    SignerDevice?,
  )
  get _values => (
    id,
    network,
    scriptType,
    derivationPath,
    label,
    isDefault,
    registration.signer,
    registration.masterFingerprint,
    registration.secretFingerprint,
    registration.birthday,
    balanceSat,
    signerDevice,
  );

  @override
  bool operator ==(Object other) =>
      other is SendSource && _values == other._values;

  @override
  int get hashCode => _values.hashCode;
}
