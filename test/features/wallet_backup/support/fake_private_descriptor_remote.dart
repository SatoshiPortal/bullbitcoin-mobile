import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/private_descriptor_record.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/private_descriptor_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:crypto/crypto.dart';

/// An in-memory descriptor record service with the contract's semantics:
/// records are immutable, addressed by publisher and ciphertext hash, and a
/// token can carry records from several publishers.
final class FakePrivateDescriptorRemote
    implements PrivateDescriptorRemoteRepository {
  final List<StoredDescriptorRecord> stored = [];
  final List<List<String>> lookedUp = [];
  WalletBackupFailure? storeFailure;
  WalletBackupFailure? lookupFailure;
  bool incomplete = false;
  DateTime now = DateTime.utc(2027);

  /// Files [ciphertext] under [tokens] as some other publisher would have.
  void publishForeign({
    required Uint8List ciphertext,
    required List<String> tokens,
    String publisher = 'another-publisher',
  }) => stored.add(
    StoredDescriptorRecord(
      publisher,
      Uint8List.fromList(ciphertext),
      tokens,
      now,
    ),
  );

  @override
  Future<Result<DateTime, WalletBackupFailure>> store({
    required WalletBackupAuthentication authentication,
    required Uint8List ciphertext,
    required List<String> lookupTokens,
  }) async {
    if (storeFailure case final failure?) return Err(failure);
    final hash = sha256.convert(ciphertext).toString();
    for (final record in stored) {
      if (record.publisher != authentication.publicKeyHex ||
          record.hash != hash) {
        continue;
      }
      return record.tokens.join() == lookupTokens.join()
          ? Ok(record.createdAt)
          : const Err(WalletBackupHeadConflictFailure());
    }
    stored.add(
      StoredDescriptorRecord(
        authentication.publicKeyHex,
        Uint8List.fromList(ciphertext),
        lookupTokens,
        now,
      ),
    );
    return Ok(now);
  }

  @override
  Future<Result<PrivateDescriptorLookup, WalletBackupFailure>> lookup(
    List<String> lookupTokens,
  ) async {
    lookedUp.add(lookupTokens);
    if (lookupFailure case final failure?) return Err(failure);
    return Ok(
      PrivateDescriptorLookup(
        records: [
          for (final record in stored.reversed)
            if (record.tokens.any(lookupTokens.contains))
              PrivateDescriptorRecord(
                ciphertext: record.ciphertext,
                ciphertextSha256: record.hash,
                createdAt: record.createdAt,
              ),
        ],
        incomplete: incomplete,
      ),
    );
  }
}

final class StoredDescriptorRecord {
  final String publisher;
  final Uint8List ciphertext;
  final List<String> tokens;
  final DateTime createdAt;
  final String hash;

  StoredDescriptorRecord(
    this.publisher,
    this.ciphertext,
    this.tokens,
    this.createdAt,
  ) : hash = sha256.convert(ciphertext).toString();
}
