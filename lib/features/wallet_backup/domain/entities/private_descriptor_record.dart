import 'dart:typed_data';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/private_descriptor_protocol.dart';

/// One stored descriptor record, exactly as the server returned it.
///
/// The server has no way to tell whether a record belongs to the token it was
/// found under, so this is an untrusted candidate: the caller decrypts it,
/// authenticates its format and proves account membership before using it.
final class PrivateDescriptorRecord {
  final Uint8List ciphertext;
  final String ciphertextSha256;
  final DateTime createdAt;

  PrivateDescriptorRecord({
    required Uint8List ciphertext,
    required this.ciphertextSha256,
    required this.createdAt,
  }) : ciphertext = ciphertext.asUnmodifiableView() {
    if (ciphertext.isEmpty ||
        ciphertext.length > privateDescriptorMaxCiphertextBytes ||
        !isWalletBackupHash(ciphertextSha256)) {
      throw ArgumentError('Invalid private descriptor record');
    }
  }
}

/// What a lookup found, newest first.
///
/// [incomplete] is the server saying its page was truncated. There is no
/// continuation cursor in this version, so it must be shown as a search that
/// did not finish and never reported as a complete absence.
final class PrivateDescriptorLookup {
  final List<PrivateDescriptorRecord> records;
  final bool incomplete;

  PrivateDescriptorLookup({
    required Iterable<PrivateDescriptorRecord> records,
    required this.incomplete,
  }) : records = List.unmodifiable(records);
}
