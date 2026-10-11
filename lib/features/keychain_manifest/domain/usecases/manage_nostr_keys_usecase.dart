import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_path.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';
import 'package:meta/meta.dart';

final class GetNostrKeysUsecase {
  final NostrKeyRepository _repository;

  const GetNostrKeysUsecase(this._repository);

  @useResult
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>> execute() =>
      _repository.getAll();
}

final class WatchNostrKeysUsecase {
  final NostrKeyRepository _repository;

  const WatchNostrKeysUsecase(this._repository);

  Stream<void> execute() => _repository.changes;
}

final class CreateNostrKeyUsecase {
  final NostrIdentityFacade _identities;
  final NostrKeyRepository _repository;

  const CreateNostrKeyUsecase(this._identities, this._repository);

  @useResult
  Future<Result<NostrKeyRecord, KeychainManifestFailure>> execute({
    required String purpose,
    String description = '',
    DateTime? now,
  }) async {
    try {
      final Secret seed;
      switch (await _identities.defaultSecret()) {
        case Ok(:final value):
          seed = value;
        case Err():
          return const Err(KeychainManifestSeedFailure());
      }
      switch (await _repository.getAll()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final fingerprint = seed.id.hex;
          var identity = 1;
          for (final entry in value.where(
            (entry) => entry.parentFingerprint == fingerprint,
          )) {
            if (entry.identity >= identity) identity = entry.identity + 1;
          }
          if (isNostrAppReservedIdentity(identity)) {
            identity = 200;
          }
          final publicKey = switch (await seed.derive.nostrPublicKey(
            identity: identity,
          )) {
            Ok(:final value) => value,
            Err() => null,
          };
          if (publicKey == null) {
            return const Err(KeychainManifestSeedFailure());
          }
          final time = (now ?? DateTime.now()).toUtc();
          final record = NostrKeyRecord(
            parentFingerprint: fingerprint,
            identity: identity,
            publicKey: publicKey,
            purpose: purpose.trim(),
            description: description.trim(),
            createdAt: time,
            updatedAt: time,
          );
          return (await _repository.insert(record)).map((_) => record);
      }
    } on FormatException {
      return const Err(KeychainManifestInvalidKeyFailure());
    } on Exception {
      return const Err(KeychainManifestSeedFailure());
    }
  }
}
