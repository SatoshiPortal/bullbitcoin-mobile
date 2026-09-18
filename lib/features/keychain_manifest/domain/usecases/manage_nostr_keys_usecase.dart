import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
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
  final GetDefaultSeedUsecase _getDefaultSeed;
  final GetSettingsUsecase _getSettings;
  final NostrKeyRepository _repository;

  const CreateNostrKeyUsecase(
    this._getDefaultSeed,
    this._getSettings,
    this._repository,
  );

  @useResult
  Future<Result<NostrKeyRecord, KeychainManifestFailure>> execute({
    required String purpose,
    String description = '',
    DateTime? now,
  }) async {
    try {
      final settings = await _getSettings.execute();
      final seed = await _getDefaultSeed.execute(
        environment: settings.environment,
      );
      switch (await _repository.getAll()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final fingerprint = seed.masterFingerprint.toLowerCase();
          var identity = 1;
          for (final entry in value.where(
            (entry) => entry.parentFingerprint == fingerprint,
          )) {
            if (entry.identity >= identity) identity = entry.identity + 1;
          }
          if (Bip85Reservations.isNostrAppReservedIdentity(identity)) {
            identity = 200;
          }
          final publicKey = NostrKeyDeriver.publicKey(seed, identity);
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

final class RestoreNostrKeyUsecase {
  final NostrKeyRepository _repository;

  const RestoreNostrKeyUsecase(this._repository);

  @useResult
  Future<Result<void, KeychainManifestFailure>> execute(
    NostrKeyRecord record,
  ) => _repository.restore(record);
}

/// Returned only to the sealed reveal view within this feature.
final class RevealedNostrSecret {
  final String nsec;

  const RevealedNostrSecret(this.nsec);

  @override
  String toString() => 'RevealedNostrSecret(<redacted>)';
}

final class RevealNostrKeyUsecase {
  final GetDefaultSeedUsecase _getDefaultSeed;
  final GetSettingsUsecase _getSettings;

  const RevealNostrKeyUsecase(this._getDefaultSeed, this._getSettings);

  @useResult
  Future<Result<RevealedNostrSecret, KeychainManifestFailure>> execute(
    NostrKeyRecord record,
  ) async {
    try {
      final settings = await _getSettings.execute();
      final seed = await _getDefaultSeed.execute(
        environment: settings.environment,
      );
      return Ok(RevealedNostrSecret(NostrKeyDeriver.reveal(seed, record)));
    } on FormatException {
      return const Err(KeychainManifestInvalidKeyFailure());
    } on Exception {
      return const Err(KeychainManifestSeedFailure());
    }
  }
}
