import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/private_descriptor_record.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:meta/meta.dart';

abstract interface class PrivateDescriptorRemoteRepository {
  /// Stores one immutable record under [lookupTokens].
  ///
  /// Records are addressed by their ciphertext hash within the publisher, so
  /// re-sending identical content is idempotent and a renewal is another
  /// record rather than an overwrite.
  @useResult
  Future<Result<DateTime, WalletBackupFailure>> store({
    required WalletBackupAuthentication authentication,
    required Uint8List ciphertext,
    required List<String> lookupTokens,
  });

  /// Reads one page of the records published under [lookupTokens], by any
  /// publisher, newest first.
  ///
  /// Unsigned: knowing a token is the read capability. An unknown token is an
  /// empty result, not an error, and says nothing about whether the vault was
  /// ever published. [cursor] is a page's own [PrivateDescriptorLookupPage
  /// .nextCursor], returned verbatim to read what follows it.
  @useResult
  Future<Result<PrivateDescriptorLookupPage, WalletBackupFailure>> lookup(
    List<String> lookupTokens, {
    String? cursor,
  });
}
