import 'package:meta/meta.dart';
import 'package:physical_backup_verification/physical_backup_verification.dart';
import 'package:primitives/primitives.dart';

import '../backup_records.dart';
import '../backup_wallet.dart';
import '../test_wallet_backup_failure.dart';

class CompleteBackupVerificationUsecase {
  final BackupRecords _records;

  const CompleteBackupVerificationUsecase(this._records);

  @useResult
  Future<Result<void, TestWalletBackupFailure>> execute(
    BackupWallet wallet,
    PhysicalBackupProof proof,
  ) async {
    if (wallet.fingerprint != proof.fingerprint) {
      return const Err(TestWalletBackupCompletionFailure());
    }
    return (await _records(wallet.network).recordPhysicalVerification(
      walletId: wallet.id,
      fingerprint: proof.fingerprint,
    )).mapErr((_) => const TestWalletBackupCompletionFailure());
  }
}
