import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/private_descriptor_record.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/private_descriptor_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

typedef DeriveDescriptorLookupToken = String? Function(String accountKeyInput);

/// Finds every descriptor record published under one cosigner's account key.
///
/// The results are candidates, not answers: the server cannot tell whether a
/// record belongs to the token it was filed under, so the caller decrypts and
/// proves membership. An empty result says nothing about whether the vault was
/// ever published.
final class LookupPrivateDescriptorsUsecase {
  final DeriveDescriptorLookupToken _lookupToken;
  final PrivateDescriptorRemoteRepository _remote;

  const LookupPrivateDescriptorsUsecase(this._lookupToken, this._remote);

  Future<Result<PrivateDescriptorLookup, WalletBackupFailure>> execute(
    String accountKeyInput,
  ) async {
    final token = _lookupToken(accountKeyInput);
    if (token == null) {
      return const Err(WalletBackupInvalidAccountKeyFailure());
    }
    return _remote.lookup([token]);
  }
}
