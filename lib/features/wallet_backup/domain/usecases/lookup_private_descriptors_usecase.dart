import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/private_descriptor_record.dart';
import 'package:bb_mobile/features/wallet_backup/domain/private_descriptor_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/private_descriptor_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

typedef DeriveDescriptorLookupToken = String? Function(String accountKeyInput);

/// Finds every descriptor record published under one cosigner's account key.
///
/// The server answers one page at a time, so this follows the pages it hands
/// back until the history ends. It stops at a bounded number of pages and
/// records, and says the search did not finish when it stopped early: a vault
/// whose older generations are still unread must never look absent.
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
    final records = <PrivateDescriptorRecord>[];
    String? cursor;
    for (var page = 0; page < privateDescriptorMaxLookupPages; page++) {
      final PrivateDescriptorLookupPage found;
      switch (await _remote.lookup([token], cursor: cursor)) {
        case Err(:final failure):
          // Pages already read are candidates worth trying, but the history
          // behind the failure is unread.
          return records.isEmpty
              ? Err(failure)
              : Ok(PrivateDescriptorLookup(records: records, incomplete: true));
        case Ok(:final value):
          found = value;
      }
      records.addAll(found.records);
      cursor = found.nextCursor;
      if (cursor == null) {
        return Ok(PrivateDescriptorLookup(records: records, incomplete: false));
      }
      if (records.length >= privateDescriptorMaxLookupRecords) break;
    }
    return Ok(PrivateDescriptorLookup(records: records, incomplete: true));
  }
}
