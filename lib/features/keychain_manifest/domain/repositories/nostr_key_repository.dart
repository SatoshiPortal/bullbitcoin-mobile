import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:meta/meta.dart';

abstract interface class NostrKeyRepository {
  Stream<void> get changes;

  @useResult
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>> getAll();

  @useResult
  Future<Result<void, KeychainManifestFailure>> insert(NostrKeyRecord record);

  @useResult
  Future<Result<void, KeychainManifestFailure>> restore(NostrKeyRecord record);

  @useResult
  Future<Result<void, KeychainManifestFailure>> update(
    NostrKeyRecord record, {
    required DateTime expectedUpdatedAt,
  });
}
