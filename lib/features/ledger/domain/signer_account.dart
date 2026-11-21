import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:primitives/primitives.dart';

/// Public account data read from a hardware signer; contains no private keys.
final class SignerAccount {
  final String masterFingerprint;
  final String derivationPath;
  final String xpub;
  final ScriptType scriptType;
  final SignerDeviceEntity device;
  final NetworkEnv network;

  const SignerAccount({
    required this.masterFingerprint,
    required this.derivationPath,
    required this.xpub,
    required this.scriptType,
    required this.device,
    required this.network,
  });
}
