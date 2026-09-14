import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_event.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/nostr_descriptor_repository.dart';
import 'package:bb_mobile/features/bullvault/data/vault_descriptor_publication_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/nostr_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/vault_descriptor_publication.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:meta/meta.dart';

/// Publishes one vault's descriptor, sealed to its backup words, on the
/// configured relays.
///
/// Acceptance by at least one relay is success. It is not verification: only a
/// read-back that decrypts to the same canonical descriptor proves recovery.
///
/// The signed event is written down before the first send and reused for every
/// later one, so an interrupted publication resends the same event rather than
/// sealing a second one for a descriptor that already has one.
final class PublishDescriptorToNostrUsecase {
  final BullVaultRepository _repository;
  final VaultDescriptorPublicationRepository _publications;
  final NostrIdentityFacade _identity;
  final NostrDescriptorRepository _nostr;

  const PublishDescriptorToNostrUsecase(
    this._repository,
    this._publications,
    this._identity,
    this._nostr,
  );

  @useResult
  Future<Result<NostrDescriptorPublication, BullVaultFailure>> execute(
    String walletId, {
    NostrSession? session,
  }) async {
    final BullVaultRecord record;
    switch (await _repository.getByWalletId(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final stored?) when stored.deservesDescriptorBackup:
        record = stored;
      case Ok():
        return const Err(BullVaultInvalidRecoveryFailure());
    }
    final BackupCredential credential;
    switch (await _identity.backupCredential()) {
      case Err():
        return const Err(BullVaultBackupCredentialFailure());
      case Ok(:final value):
        credential = value;
    }
    final List<VaultDescriptorPublication> rows;
    switch (await _publications.load(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        rows = value;
    }
    final policy = record.recoveryPackage.policy;
    final stored = _storedEvent(rows);
    if (stored != null && stored.author != credential.nostrPublicKeyHex) {
      return const Err(BullVaultForeignBackupCredentialFailure());
    }
    final NostrDescriptorPublication publication;
    try {
      var event = stored;
      if (event == null) {
        event = await _nostr.seal(
          credential: credential,
          descriptor: policy.descriptor,
          network: policy.network,
        );
        final prepared = await _publications.prepare(
          walletId: walletId,
          destination: VaultBackupDestination.nostr,
          artifact: Uint8List.fromList(utf8.encode(jsonEncode(event.toJson()))),
        );
        // Nothing is sent until the bytes survive a restart.
        if (prepared case Err(:final failure)) return Err(failure);
      }
      publication = await _nostr.publish(event, session ?? NostrSession());
    } on Exception {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
    final recorded = publication.accepted
        ? await _publications.markSent(
            walletId: walletId,
            destination: VaultBackupDestination.nostr,
          )
        : await _publications.markFailed(
            walletId: walletId,
            destination: VaultBackupDestination.nostr,
          );
    if (recorded case Err(:final failure)) return Err(failure);
    return publication.accepted
        ? Ok(publication)
        : const Err(BullVaultNostrUnreachableFailure());
  }

  /// The event this vault already owes the relays, or null when it has none.
  ///
  /// The caller compares its author with the credential in hand: a vault
  /// recovered onto another phone carries no right to republish under that
  /// phone's identity, and re-sealing one rather than keeping it is what moves
  /// the vault into a second recovery namespace.
  NostrEvent? _storedEvent(List<VaultDescriptorPublication> rows) {
    final artifact = rows
        .where((row) => row.destination == VaultBackupDestination.nostr)
        .map((row) => row.artifact)
        .firstOrNull;
    if (artifact == null) return null;
    try {
      return NostrEvent.parse(
        jsonDecode(utf8.decode(artifact)) as Map<String, dynamic>,
        maxContentBytes: NostrDescriptorRepository.maxContentBytes,
      );
    } on Exception {
      return null;
    }
  }
}
