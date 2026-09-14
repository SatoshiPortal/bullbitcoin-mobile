import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/data/vault_descriptor_publication_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/nostr_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/vault_descriptor_publication.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_server_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/discover_descriptors_on_nostr_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_private_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/publish_descriptor_to_nostr_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/verify_nostr_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/can_delete_bullvault_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/vault_recovery_notice.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_backup_changes_usecase.dart';

export 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_descriptor_backup.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/nostr_descriptor_backup.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/vault_descriptor_publication.dart';
export 'package:bb_mobile/features/bullvault/domain/usecases/verify_nostr_descriptor_backup_usecase.dart'
    show NostrDescriptorVerification;
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
export 'package:bb_mobile/features/bullvault/public/bullvault_contributions.dart';
export 'package:bb_mobile/features/bullvault/ui/bullvault_recovery_package_share.dart'
    show openBullVaultBackupDestinations, shareBullVaultRecoveryPackage;
export 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart'
    show BullVaultRouter;

class BullVaultFacade {
  static const createRouteName = 'bullVaultCreate';

  /// The recovery landing. The route lives in `backup_settings`, which is the
  /// one place that can compose the vault, backup and relay searches, but the
  /// name stays here so every existing caller keeps working.
  static const restoreRouteName = 'bullVaultRestore';

  /// The landing's "Import descriptor" child, built by [BullVaultRouter].
  static const importDescriptorRouteName = 'bullVaultImportDescriptor';
  static const settingsRouteName = 'bullVaultSettings';
  static const menuRouteName = 'bullVaultMenu';
  static const policyRouteName = 'bullVaultPolicy';
  static const keysRouteName = 'bullVaultKeys';
  static const backupRouteName = 'bullVaultBackupRecovery';

  /// Additional backup protection. Registered by `backup_settings`, which owns
  /// the destination journey and the server transport it needs.
  static const backupDestinationsRouteName = 'bullVaultBackupDestinations';
  static const renewRouteName = 'bullVaultRenew';
  static const importCosignerRouteName = 'bullVaultImportCosigner';

  final CanDeleteBullVaultWalletUsecase _canDeleteWalletUsecase;
  final BullVaultRepository _repository;
  final RestoreBullVaultUsecase _restoreUsecase;
  final WatchBullVaultBackupChangesUsecase _watchBackupChanges;
  final EncodePrivateDescriptorBackupUsecase _encodePrivateDescriptor;
  final PublishDescriptorToNostrUsecase _publishToNostr;
  final DiscoverDescriptorsOnNostrUsecase _discoverOnNostr;
  final VerifyNostrDescriptorBackupUsecase _verifyOnNostr;
  final PrepareServerDescriptorBackupUsecase _prepareForServer;
  final VaultDescriptorPublicationRepository _publications;
  final VaultRecoveryNotice _recoveryNotice;

  const BullVaultFacade(
    this._canDeleteWalletUsecase,
    this._repository,
    this._restoreUsecase,
    this._watchBackupChanges,
    this._encodePrivateDescriptor,
    this._publishToNostr,
    this._discoverOnNostr,
    this._verifyOnNostr,
    this._prepareForServer,
    this._publications,
    this._recoveryNotice,
  );

  /// Announces on the home screen that a recovery put a vault on this device.
  ///
  /// Only a persisted wallet is worth announcing: a discovery that found
  /// nothing, or found a vault already here, is not a recovery.
  void recordVaultRecovered() => _recoveryNotice.record();

  /// Initial wake-up and committed changes whose revisions are already saved.
  Stream<void> watchBackupChanges() => _watchBackupChanges.execute();

  /// Every vault record on this device, for the backup's vaults section.
  @useResult
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> listRecords() =>
      _repository.getAll();

  /// The recovery package exactly as the vault feature shares it.
  String encodeRecoveryPackage(BullVaultRecoveryPackage package) =>
      _repository.encodeRecoveryPackage(package);

  /// Structural read of a recovery package; null when it is not one. Does not
  /// check that the mobile key derives from a local seed — restore does.
  BullVaultRecoveryPackage? decodeRecoveryPackage(String source) =>
      switch (_repository.decodeRecoveryPackage(source)) {
        Ok(:final value) => value,
        Err() => null,
      };

  /// Restores a vault from its recovery package, creating the wallet if it is
  /// absent and accepting a matching wallet that already exists.
  ///
  /// [status] replays a backed-up generation under its own recorded lifecycle
  /// status instead of making it the vault in force.
  @useResult
  Future<Result<BullVaultRestoreResult, BullVaultFailure>>
  restoreFromRecoveryPackage({
    required String source,
    required String label,
    BullVaultLifecycleStatus status = BullVaultLifecycleStatus.active,
  }) => _restoreUsecase.execute(
    kind: BullVaultRestoreInputKind.recoveryPackage,
    source: source,
    label: label,
    status: status,
  );

  /// Restores a vault from its bare descriptor, without the extra facts a
  /// recovery package carries. Every rule the package path applies still holds.
  @useResult
  Future<Result<BullVaultRestoreResult, BullVaultFailure>>
  restoreFromDescriptor({required String source, required String label}) =>
      _restoreUsecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: source,
        label: label,
      );

  /// The vault's descriptor sealed for each of its cosigners, with the lookup
  /// alias each of them can find it under.
  @useResult
  Future<Result<BullVaultDescriptorBackup, BullVaultFailure>>
  encodePrivateDescriptorBackup(String walletId) =>
      _encodePrivateDescriptor.execute(walletId);

  /// Opens a private descriptor backup with one cosigner's account key, proving
  /// the descriptor inside names that exact account before returning it.
  @useResult
  Result<BullVaultDescriptorBackup, BullVaultFailure>
  decodePrivateDescriptorBackup({
    required Uint8List bytes,
    required String accountKeyInput,
  }) => _repository.decodePrivateDescriptorBackup(
    bytes: bytes,
    accountKeyInput: accountKeyInput,
  );

  /// Publishes this vault's descriptor, sealed to its backup words, on the
  /// configured relays. At least one acceptance is success; proof of recovery
  /// is the separate read-back below.
  @useResult
  Future<Result<NostrDescriptorPublication, BullVaultFailure>>
  publishDescriptorToNostr(String walletId, {NostrSession? session}) =>
      _publishToNostr.execute(walletId, session: session);

  /// Every vault descriptor one set of backup words published, validated and
  /// deduplicated, with whether the search could finish. Nothing is imported:
  /// the caller decides, and imports through the existing restore path.
  ///
  /// [words] searches on another wallet's behalf; without them the search uses
  /// this device's own credential.
  @useResult
  Future<Result<NostrDescriptorSearch, BullVaultFailure>>
  discoverDescriptorsOnNostr({String? words, NostrSession? session}) =>
      _discoverOnNostr.execute(words: words, session: session);

  /// Reads this vault's descriptor back from the relays and compares it with
  /// the one in force.
  @useResult
  Future<Result<NostrDescriptorVerification, BullVaultFailure>>
  verifyNostrDescriptorBackup(String walletId, {NostrSession? session}) =>
      _verifyOnNostr.execute(walletId, session: session);

  /// What this vault has agreed to publish where, and how far each got.
  @useResult
  Future<Result<List<VaultDescriptorPublication>, BullVaultFailure>>
  descriptorPublications(String walletId) => _publications.load(walletId);

  /// Records the person's choice of destination. Nothing else writes it, and
  /// turning one off never deletes the artifact already sent to it.
  @useResult
  Future<Result<void, BullVaultFailure>> setDescriptorBackupDestination({
    required String walletId,
    required VaultBackupDestination destination,
    required bool enabled,
  }) => _publications.setEnabled(
    walletId: walletId,
    destination: destination,
    enabled: enabled,
  );

  /// The exact BIP138 artifact this vault owes the descriptor server, sealed
  /// once and written down before anything is sent.
  @useResult
  Future<Result<BullVaultDescriptorBackup, BullVaultFailure>>
  prepareServerDescriptorBackup(String walletId) =>
      _prepareForServer.execute(walletId);

  /// Records what a destination did with the artifact it was sent.
  @useResult
  Future<Result<void, BullVaultFailure>> recordDescriptorPublicationSent({
    required String walletId,
    required VaultBackupDestination destination,
    required bool accepted,
  }) => accepted
      ? _publications.markSent(walletId: walletId, destination: destination)
      : _publications.markFailed(walletId: walletId, destination: destination);

  /// Records that the artifact was read back from a destination and matched.
  @useResult
  Future<Result<void, BullVaultFailure>> recordDescriptorPublicationVerified({
    required String walletId,
    required VaultBackupDestination destination,
  }) =>
      _publications.markVerified(walletId: walletId, destination: destination);

  /// The lookup alias an account key publishes under, or null when the input is
  /// not an account key. Accepts a bare xpub, an origin-qualified expression or
  /// a descriptor naming one account.
  String? descriptorLookupToken(String accountKeyInput) =>
      _repository.descriptorLookupToken(accountKeyInput);

  @useResult
  Future<Result<bool, BullVaultFailure>> isBullVaultWallet(
    String walletId,
  ) async => switch (await _canDeleteWalletUsecase.execute(walletId)) {
    Ok(:final value) => Ok(!value),
    Err(:final failure) => Err(failure),
  };

  @useResult
  Future<Result<bool, BullVaultFailure>> canDeleteWallet(String walletId) =>
      _canDeleteWalletUsecase.execute(walletId);
}
