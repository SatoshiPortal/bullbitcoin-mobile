import 'package:primitives/primitives.dart';

import '../domain/failures.dart';
import '../domain/inventory_backup_verification.dart';
import '../domain/wallet_registration.dart';

WalletRegistration walletRegistrationForTesting({
  required String id,
  required Network network,
  bool isDefault = false,
  ScriptType scriptType = ScriptType.bip84,
  String? derivationPath,
  String? label,
  WalletSigner signer = WalletSigner.none,
  Fingerprint? masterFingerprint,
  Fingerprint? secretFingerprint,
}) => WalletRegistration(
  id: id,
  network: network,
  scriptType: scriptType,
  signer: signer,
  masterFingerprint: masterFingerprint,
  secretFingerprint: secretFingerprint,
  derivationPath: derivationPath,
  label: label,
  birthday: null,
  isDefault: isDefault,
);

WalletSelection walletSelectionForTesting(
  List<WalletRegistration> wallets, {
  bool isComplete = true,
}) => WalletSelection(wallets, isComplete: isComplete);

/// Backup proofs a test states per seed, for the inventory guard and the
/// deletion check alike.
///
/// A seed this fake does not list is [BackupProof.missing] — the fail-closed
/// answer — so a test that forgets one can never prove a backup by accident.
/// A store that cannot be read at all is the other answer the guard must
/// respect; the test that needs it states it locally, in `test/`.
final class FakeInventoryBackups implements InventoryBackupVerification {
  final Set<Fingerprint> verified;

  const FakeInventoryBackups({this.verified = const {}});

  @override
  Future<Result<BackupProof, SecretFailure>> verify(
    Fingerprint secret, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async => Ok(
    verified.contains(secret) ? BackupProof.verified : BackupProof.missing,
  );
}
