import 'package:signers/src/signer_device.dart';
import 'package:primitives/primitives.dart';

/// Public account data read from a hardware signer; contains no private keys.
final class SignerAccount {
  final String masterFingerprint;
  final String derivationPath;
  final String xpub;
  final ScriptType scriptType;
  final SignerDevice device;
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
