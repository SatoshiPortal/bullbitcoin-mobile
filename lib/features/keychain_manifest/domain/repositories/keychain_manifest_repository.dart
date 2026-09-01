import 'dart:async';

import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

enum KeychainManifestWriteOrigin { local, recovery }

/// How [KeychainManifestRepository.restoreSnapshot] reconciles a restored
/// record with the one already stored under the same entry id.
enum KeychainManifestRestorePolicy {
  /// Identical identity metadata: the newest `updatedAt` wins, so a restored
  /// newer label or hint is applied and older restored text never clobbers
  /// newer local text. Different identity metadata under the same entry id is
  /// reported as a conflict and never merged (spec 6.5).
  keepNewest,
}

/// What one [KeychainManifestRepository.restoreSnapshot] pass did.
///
/// [conflicts] holds the entry ids the policy refused, so recovery can report
/// them instead of claiming a complete apply.
final class KeychainManifestRestoreReport {
  final int applied;
  final int unchanged;
  final List<String> conflicts;

  KeychainManifestRestoreReport({
    this.applied = 0,
    this.unchanged = 0,
    Iterable<String> conflicts = const [],
  }) : conflicts = List.unmodifiable(conflicts);

  int get restored => applied + unchanged;
}

/// The persistent recovery inventory.
///
/// Every write is one named intent (spec F11). There is deliberately no generic
/// save: a local edit, a deterministic re-derivation, and a recovery apply want
/// different conflict answers, and a shared helper can only guess.
abstract interface class KeychainManifestRepository {
  Stream<void> watchLocalChanges();

  @useResult
  Future<Result<List<KeychainManifestEntry>, KeychainManifestFailure>> fetch(
    Fingerprint parentFingerprint,
  );

  /// Replaces the deterministic seed-derived wallet materializations of
  /// [parentFingerprint] with [entries].
  ///
  /// Records the app can re-derive from the seed at any time are owned by this
  /// operation. Imported-mnemonic and passphrase records are not: they exist
  /// only because the user made them, so ones absent from [entries] are kept.
  @useResult
  Future<Result<void, KeychainManifestFailure>> replaceSeedWalletInventory(
    Fingerprint parentFingerprint,
    List<KeychainManifestEntry> entries,
  );

  /// Inserts or updates one directly recorded wallet materialization.
  ///
  /// Identity is the combined public descriptor the record carries, or its
  /// wallet id when it carries none. A stored record whose identity differs is
  /// a conflict even when the four-byte seed fingerprint matches — that
  /// fingerprint is a lookup hint, never an identity (spec 6.5). Label and hint
  /// are not identity: changing them updates the stored record.
  @useResult
  Future<Result<void, KeychainManifestFailure>> upsertPassphraseWallet(
    KeychainManifestEntry record,
  );

  /// Updates the display label and passphrase hint the manifest owns
  /// (decision 2).
  ///
  /// Monotonic: [updatedAt] must be newer than the stored revision. Two
  /// different texts claiming the same instant cannot be ordered, so an equal
  /// timestamp carrying different content is a conflict rather than a coin
  /// toss. Writing back what is already stored succeeds and changes nothing.
  @useResult
  Future<Result<void, KeychainManifestFailure>> updatePassphraseLabelHint({
    required Fingerprint parentFingerprint,
    required String walletId,
    KeychainManifestEdit<String?>? label,
    KeychainManifestEdit<String?>? hint,
    required int updatedAt,
  });

  /// Forgets one wallet's recovery record.
  @useResult
  Future<Result<void, KeychainManifestFailure>> removePassphraseWallet({
    required Fingerprint parentFingerprint,
    required String walletId,
  });

  /// Applies the wallet materializations of a recovered [manifest] under
  /// [policy].
  ///
  /// Recovery-origin: it neither raises the backup dirty signal nor publishes a
  /// local change, so restoring a snapshot cannot publish it straight back.
  /// Entries that do not carry exactly one wallet materialization are reported
  /// as conflicts; the Nostr materializations of a snapshot are restored by
  /// their own use case, which has the deriver needed to verify them.
  @useResult
  Future<Result<KeychainManifestRestoreReport, KeychainManifestFailure>>
  restoreSnapshot(
    KeychainManifest manifest, {
    KeychainManifestRestorePolicy policy,
  });

  /// Adds one deterministic Nostr key materialization.
  ///
  /// Writing back an identical record succeeds and changes nothing; a stored
  /// record with different key material is a conflict. Later metadata edits go
  /// through [updateNostrMetadata].
  @useResult
  Future<Result<void, KeychainManifestFailure>> insertNostrKey(
    KeychainManifestEntry record, {
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  });

  @useResult
  Future<Result<void, KeychainManifestFailure>> updateNostrMetadata({
    required Fingerprint parentFingerprint,
    required String entryId,
    required String purpose,
    String? description,
    required int updatedAt,
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  });

  Future<void> close();
}
