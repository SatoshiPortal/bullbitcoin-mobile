import 'dart:io';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:drift/drift.dart' show Value;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart'
    show
        LegacyImportDeferred,
        LegacyImportFailure,
        LegacyImportVerificationFailed,
        LegacyOwnerFailure,
        LegacyOwnerFailureCause;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/data.dart'
    show
        inventorySessionChangedFailure,
        inventoryCredentialRequiredFailure,
        inventoryLockedFailure,
        invalidBip85HexLengthFailure,
        unreadableBip85RecordFailure;

import '../data/access_repository.dart';
import '../data/backup_guard.dart';
import '../data/derivation_repository.dart';
import '../data/inventory_import.dart';
import '../data/inventory_repository.dart';
import '../data/inventory_store.dart';
import '../data/secrets_database.drift.dart' show DerivationsCompanion;
import '../domain/access_attempt.dart';
import '../domain/backup_candidate.dart';
import '../domain/domain.dart';
import '../domain/inventory_backup_verification.dart';
import '../domain/metadata_backup_wallet.dart';
import '../domain/recorded_derivation.dart';
import '../domain/registered_wallet.dart';
import '../domain/wallet_registration.dart';
import 'extensions.dart';
import 'secret.dart';
import 'secrets.dart';
import 'seed_reference_port.dart';
import 'wallet_inventory.dart';

part 'bip85_derivations.dart';

/// The foreground wallet inventory. Access starts with the persisted policy.
/// Lock invalidates any pending read and the next operation checks the session.
final class SecretsInventory implements WalletInventory, SeedReferencePort {
  final InventoryStore _store;
  final AccessRepository _access;
  final InventoryRepository _wallets;
  final DerivationRepository _derivations;
  final BackupGuard _guard;
  bool _unlocked;
  var _session = 0;

  SecretsInventory._(
    this._store,
    this._access,
    this._guard,
    bool initiallyProtected,
  ) : _wallets = InventoryRepository(_store.database),
      _derivations = DerivationRepository(_store.database),
      _unlocked = !initiallyProtected;

  /// Open an existing, admitted inventory. A missing receipt blocks publication.
  ///
  /// [backupVerification] is the composition's one verifier, bound here before
  /// the capability exists. Without it the inventory refuses every decision that
  /// needs a backup proof; no operation lets a caller supply its own.
  @useResult
  static Future<Result<SecretsInventory, DatabaseOpenFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    InventoryBackupVerification? backupVerification,
  }) async {
    final opened = await _openReady(file, admission);
    switch (opened) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (await reconcileInventoryAccess(value.database) case Err(
          :final failure,
        )) {
          await value.close();
          return Err(inventoryReadinessFailure(failure));
        }
        final guard = BackupGuard(backupVerification, value.database);
        final access = AccessRepository(value.database, guard);
        switch (await access.protectionAtOpen()) {
          case Err(:final failure):
            await value.close();
            return Err(failure);
          case Ok(value: final protected):
            return Ok(SecretsInventory._(value, access, guard, protected));
        }
    }
  }

  @useResult
  Future<Result<bool, SecretFailure>> isProtected() => _access.isProtected();

  @useResult
  Future<Result<AccessAttempt, SecretFailure>> accessStatus() =>
      _access.status();

  @useResult
  Future<Result<AccessAttempt, SecretFailure>> unlock(String candidate) async {
    final current = _session;
    final attempt = await _access.unlock(candidate);
    if (current != _session) {
      return const Err(inventorySessionChangedFailure);
    }
    if (attempt case Ok(value: AccessAttempt(accepted: true))) _unlocked = true;
    return attempt;
  }

  void lock() {
    _session++;
    _unlocked = false;
  }

  @useResult
  Future<Result<void, SecretFailure>> resumeUnprotected() =>
      _inSession(requireUnlocked: false, (session) async {
        switch (await _access.isProtected()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: true):
            return const Err(inventoryCredentialRequiredFailure);
          case Ok(value: false):
            if (session == _session) _unlocked = true;
            return const Ok(null);
        }
      });

  /// The secrets of the active view without a tested backup, by the same rule
  /// that protecting the view applies. Empty means the view can be protected;
  /// a view holding only watch-only wallets has no seed to prove (D95) and is
  /// still not backed up. Read only: [setCredential] decides again under the
  /// write lock.
  @useResult
  Future<Result<List<Fingerprint>, SecretFailure>> unbackedSecrets() =>
      _inSession((_) => _access.unbackedSecrets());

  /// Protect the active view, or replace its PIN, from an authenticated
  /// foreground session. Protecting needs a tested backup of every secret the
  /// view holds, judged by the verifier bound at composition.
  @useResult
  Future<Result<void, SecretFailure>> setCredential(String candidate) =>
      _inSession((_) => _access.replaceCredential(candidate));

  /// Remove access protection from an authenticated foreground session.
  @useResult
  Future<Result<void, SecretFailure>> removeCredential() =>
      _inSession((_) => _access.replaceCredential(null));

  /// Permit background sync to read the active view's descriptors while locked.
  @useResult
  Future<Result<void, SecretFailure>> setBackgroundEnabled(bool enabled) =>
      _inSession((_) => _access.setBackgroundEnabled(enabled));

  @useResult
  Future<Result<List<RegisteredWallet>, SecretFailure>> listWallets() =>
      _inSession((_) => _wallets.list(defaultViewId));

  @override
  @useResult
  Future<Result<List<Fingerprint>, SecretFailure>> referencedFingerprints() =>
      _inSession((_) => _wallets.referencedFingerprints(defaultViewId));

  /// Whether the authorized view has any wallet, including on other networks.
  /// Seeds held by locally signing wallets of every view. A watch-only origin
  /// never keeps a seed alive (#2634); a locked session, an unreadable
  /// inventory or an invalid local reference cannot prove the seed unused.
  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async =>
      switch (await _inSession((_) => _wallets.custodyFingerprints())) {
        Ok(:final value) => Ok(value),
        Err() => const Err(SeedReferencesUnavailable()),
      };

  @useResult
  Future<Result<bool, SecretFailure>> hasWallets() async =>
      (await listWallets()).map((wallets) => wallets.isNotEmpty);

  /// Locally signing Bitcoin wallets and their public recovery evidence.
  @useResult
  Future<Result<List<BitcoinRecoveryWallet>, SecretFailure>>
  recoveryWallets() =>
      _inSession((_) => _wallets.recoveryWallets(defaultViewId));

  @useResult
  Future<Result<List<RegisteredWalletDescriptor>, SecretFailure>>
  listDescriptors() =>
      _inSession((_) => _wallets.descriptors(foregroundView: defaultViewId));

  @useResult
  Future<Result<RegisteredWallet?, SecretFailure>> findWallet(String id) =>
      _inSession((_) => _wallets.find(defaultViewId, id));

  @override
  @useResult
  Future<Result<WalletRegistration, SecretFailure>> readWallet(String id) =>
      _inSession((_) => _wallets.read(defaultViewId, id));

  /// Publishes a joined read only while the session that started it is live.
  /// Exceptions from [read] propagate to the caller.
  @useResult
  Future<Result<T, SecretFailure>> readInSession<T>(
    Future<T> Function() read,
  ) => _inSession((_) async => Ok(await read()));

  @override
  @useResult
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) => _inSession((_) => _wallets.listForNetwork(defaultViewId, network));

  /// Reserve the ID before preparing properties owned by other stores. The
  /// callback must not call back into this inventory. If it fails, the wallet
  /// and its membership are not published; a retry prepares its properties.
  /// When passed true, the callback must preserve backup evidence belonging to
  /// the existing secret member and refuse a conflicting wallet identity.
  @useResult
  Future<Result<void, SecretFailure>> registerWallet(
    RegisteredWallet wallet, {
    Future<Result<void, SecretFailure>> Function(bool existingSecretMember)?
    prepareProperties,
  }) => _inSession(
    (_) => _wallets.register(
      wallet,
      view: defaultViewId,
      guard: _guard,
      prepareProperties: prepareProperties,
    ),
  );

  @useResult
  Future<Result<void, SecretFailure>> setWalletProperties({
    required String id,
    required String? label,
    required DateTime? birthday,
    required bool isDefault,
  }) => _inSession(
    (_) => _wallets.updateProperties(
      view: defaultViewId,
      id: id,
      label: label,
      birthday: birthday,
      isDefault: isDefault,
    ),
  );

  @useResult
  Future<Result<void, SecretFailure>> removeWallet(String id) =>
      _inSession((_) => _wallets.remove(view: defaultViewId, id: id));

  /// Operates on historical BIP85 children in the current foreground view.
  Bip85Derivations bip85(Secrets secrets) => Bip85Derivations._(this, secrets);

  @useResult
  Future<Result<List<RecordedDerivation>, SecretFailure>> listDerivations() =>
      _inSession((_) => _derivations.list(defaultViewId));

  @useResult
  Future<Result<RecordedDerivation, SecretFailure>> reserveHexDerivation({
    required Fingerprint parent,
    required int length,
    String? alias,
  }) => _inSession(
    (_) => _derivations.reserveHex(
      view: defaultViewId,
      parent: parent,
      length: length,
      alias: alias,
    ),
  );

  @useResult
  Future<Result<RecordedDerivation, SecretFailure>> reserveMnemonicDerivation({
    required Fingerprint parent,
    required MnemonicLength length,
    required Language language,
    String? alias,
  }) => _inSession(
    (_) => _derivations.reserveMnemonic(
      view: defaultViewId,
      parent: parent,
      length: length,
      language: language,
      alias: alias,
    ),
  );

  @useResult
  Future<Result<void, SecretFailure>> renameDerivation(
    RecordedDerivation derivation,
    String? alias,
  ) => _updateDerivation(derivation, DerivationsCompanion(alias: Value(alias)));

  @useResult
  Future<Result<void, SecretFailure>> setDerivationActive(
    RecordedDerivation derivation, {
    required bool active,
  }) => _updateDerivation(
    derivation,
    DerivationsCompanion(status: Value(active ? 'active' : 'revoked')),
  );

  Future<Result<void, SecretFailure>> _updateDerivation(
    RecordedDerivation derivation,
    DerivationsCompanion change,
  ) => _inSession(
    (_) => _derivations.update(
      view: defaultViewId,
      parentFingerprint: derivation.parentFingerprint,
      path: derivation.path,
      change: change,
    ),
  );

  Future<Result<T, SecretFailure>> _inSession<T>(
    Future<Result<T, SecretFailure>> Function(int session) run, {
    bool requireUnlocked = true,
  }) async {
    if (requireUnlocked && !_unlocked) {
      return const Err(inventoryLockedFailure);
    }
    final session = _session;
    final result = await run(session);
    return session == _session
        ? result
        : const Err(inventorySessionChangedFailure);
  }

  /// Test seam: a wallet row visible to [view] only, as a second view would
  /// hold one. No public operation can create a view yet.
  @visibleForTesting
  Future<void> insertWalletInViewForTesting({
    required String view,
    required RegisteredWallet wallet,
  }) async {
    final database = _store.database;
    await database.customStatement(
      'INSERT OR IGNORE INTO views (id, name, background_enabled) VALUES (?, ?, 1)',
      [view, view],
    );
    await database.customStatement(
      '''INSERT INTO wallets (id, secret_fingerprint, master_fingerprint, signer,
         network, xpub, external_descriptor, internal_descriptor, label, birthday,
         is_default) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        wallet.id,
        wallet.secretFingerprint,
        wallet.masterFingerprint,
        wallet.signer,
        wallet.network,
        wallet.xpub,
        wallet.externalDescriptor,
        wallet.internalDescriptor,
        wallet.label,
        wallet.birthday,
        wallet.isDefault ? 1 : 0,
      ],
    );
    await database.customStatement(
      'INSERT INTO view_members (view_id, member) VALUES (?, ?)',
      [
        view,
        wallet.secretFingerprint == null
            ? 'wallet:${wallet.id}'
            : 'secret:${wallet.secretFingerprint}',
      ],
    );
  }

  /// Test seam: makes an existing wallet visible to [view] too.
  @visibleForTesting
  Future<void> shareWalletWithViewForTesting({
    required String view,
    required String walletId,
  }) async {
    final database = _store.database;
    await database.customStatement(
      'INSERT OR IGNORE INTO views (id, name, background_enabled) VALUES (?, ?, 1)',
      [view, view],
    );
    await database.customStatement(
      'INSERT INTO view_members (view_id, member) VALUES (?, ?)',
      [view, 'wallet:$walletId'],
    );
  }

  Future<void> close() {
    lock();
    return _store.close();
  }
}

/// The metadata backup client cannot fetch raw descriptors from this view.
extension MetadataBackupInventory on SecretsInventory {
  @useResult
  Future<Result<List<MetadataBackupWallet>, SecretFailure>>
  metadataBackupWallets(Secrets secrets) => _inSession((_) async {
    final projection = await _wallets.metadataBackupWallets(defaultViewId);
    if (projection case Err(:final failure)) return Err(failure);
    final wallets =
        (projection as Ok<List<MetadataBackupWallet>, SecretFailure>).value;
    final available = <Fingerprint, bool>{};
    final verified = <MetadataBackupWallet>[];
    for (final wallet in wallets) {
      final reference = wallet.secret;
      if (reference == null) {
        verified.add(wallet);
        continue;
      }
      var present = available[reference];
      if (present == null) {
        switch (await secrets.fetch(reference)) {
          case Ok():
            present = true;
          case Err(failure: SecretNotFoundFailure()):
            present = false;
          case Err(:final failure):
            return Err(failure);
        }
        available[reference] = present;
      }
      verified.add(present ? wallet : MetadataBackupWallet(id: wallet.id));
    }
    return Ok(List.unmodifiable(verified));
  });
}

/// One live session as a backup client sees it: the durable view it reads and
/// whether the authority still holds the exact generation it was issued in.
///
/// A lock revokes it for good: reopening the same view later is a new
/// generation, so an operation started before the lock can never continue
/// after it. [view] is only an identity to partition state by; it grants
/// nothing.
final class BackupSession {
  /// The durable identifier of the view; stable across sessions.
  final String view;
  final SecretsInventory _inventory;
  final int _generation;

  BackupSession._(this.view, this._inventory, this._generation);

  /// False as soon as the session ended, including when the view was reopened.
  bool get isCurrent =>
      _inventory._unlocked && _inventory._session == _generation;
}

/// Metadata backup operations that cannot reach a seed or a descriptor
/// outside the projection above. Every operation takes the [BackupSession] it
/// belongs to and refuses to run once that session is no longer current.
extension MetadataBackupRestore on SecretsInventory {
  /// The live session. Backup state is partitioned by its [BackupSession.view]
  /// and every effect re-checks [BackupSession.isCurrent] immediately before
  /// it starts.
  @useResult
  Future<Result<BackupSession, SecretFailure>> backupSession() => _inSession(
    (generation) async => Ok(BackupSession._(defaultViewId, this, generation)),
  );

  /// The Bitcoin wallets of [network] visible in this session's view, each with
  /// a verdict of exclusivity decided by Secrets from the real memberships and
  /// the BIP138 recipient keys (see `InventoryRepository.backupCandidates`).
  /// Nothing of another view is ever returned.
  @useResult
  Future<Result<List<BackupCandidate>, SecretFailure>> backupCandidates(
    BackupSession session,
    BitcoinNetwork network,
  ) => _inBackupSession(
    session,
    (view) => _wallets.backupCandidates(view, network),
  );

  /// The visible wallet whose network and two public descriptors equal the
  /// given ones. Never matched by identifier.
  @useResult
  Future<Result<String, SecretFailure>> matchPublicWallet({
    required BackupSession session,
    required BitcoinNetwork network,
    required String external,
    required String internal,
  }) => _inBackupSession(
    session,
    (view) => _wallets.matchPublicWallet(
      view: view,
      network: network,
      external: external,
      internal: internal,
    ),
  );

  /// Attaches a label and a birthday to the matching public wallet, only
  /// where the wallet has none. Signer, device and default flag are untouched.
  @useResult
  Future<Result<({bool label, bool birthday}), SecretFailure>>
  restorePublicWalletProperties({
    required BackupSession session,
    required BitcoinNetwork network,
    required String external,
    required String internal,
    required String? label,
    required DateTime? birthday,
  }) => _inBackupSession(
    session,
    (view) => _wallets.restorePublicProperties(
      view: view,
      network: network,
      external: external,
      internal: internal,
      label: label,
      birthday: birthday,
    ),
    isWrite: true,
  );

  /// Merges archived BIP85 records of one parent. All or nothing; it can
  /// add rows and make a child more restricted, never fewer, so the next
  /// index can only rise. It does not lift any recovery block and never
  /// authorizes a new child.
  @useResult
  Future<Result<DerivationMergeReport, SecretFailure>> mergeDerivationArchive({
    required BackupSession session,
    required Fingerprint parent,
    required List<RecordedDerivation> records,
  }) => _inBackupSession(
    session,
    (view) => _derivations.merge(view: view, parent: parent, records: records),
    isWrite: true,
  );

  Future<Result<T, SecretFailure>> _inBackupSession<T>(
    BackupSession session,
    Future<Result<T, SecretFailure>> Function(String view) run, {
    bool isWrite = false,
  }) async {
    if (!session.isCurrent) {
      return const Err(inventorySessionChangedFailure);
    }
    Result<T, SecretFailure>? ran;
    final result = await _inSession((_) async => ran = await run(session.view));
    // A write whose transaction committed before the lock reports what
    // happened: hiding a committed change behind a failure would let the
    // caller retry or journal the wrong state.
    if (isWrite && result is Err) {
      if (ran case final Ok<T, SecretFailure> committed) return committed;
    }
    return result;
  }
}

/// Scope for background sync. Only descriptors in views with an active
/// background grant can leave this capability. It cannot read seeds or PINs.
final class BackgroundWalletDescriptors {
  final InventoryStore _store;
  final InventoryRepository _wallets;

  BackgroundWalletDescriptors._(this._store)
    : _wallets = InventoryRepository(_store.database);

  @useResult
  static Future<Result<BackgroundWalletDescriptors, DatabaseOpenFailure>> open({
    required File file,
    required RuntimeAdmission admission,
  }) async =>
      (await _openReady(file, admission)).map(BackgroundWalletDescriptors._);

  @useResult
  Future<Result<List<RegisteredWalletDescriptor>, SecretFailure>> list() =>
      _wallets.descriptors();

  Future<void> close() => _store.close();
}

Future<Result<InventoryStore, DatabaseOpenFailure>> _openReady(
  File file,
  RuntimeAdmission admission,
) async {
  final result = await InventoryStore.open(file, admission, existing: true);
  switch (result) {
    case Err():
      return result;
    case Ok(:final value):
      switch (await readInventoryReadiness(value.database, admitted: true)) {
        case Ok(value: OwnerReadiness.imported || OwnerReadiness.initialized):
          return result;
        case Ok():
          await value.close();
          return const Err(DatabaseNotReady());
        case Err(:final failure):
          await value.close();
          return Err(inventoryReadinessFailure(failure));
      }
  }
}

/// What a failed readiness check on an admitted inventory means to the open.
/// Each cause survives, so a caller can tell damaged data from a locked
/// keystore, contention, a newer format or a plain access error. Only
/// [DatabaseFileProblem.unreadable] and a missing key say the data is lost.
@visibleForTesting
DatabaseOpenFailure inventoryReadinessFailure(LegacyImportFailure failure) =>
    switch (failure) {
      LegacyImportDeferred() => const DatabaseKeyUnavailable(
        DatabaseKeyProblem.locked,
      ),
      LegacyOwnerFailure(:final cause) => switch (cause) {
        LegacyOwnerFailureCause.keystoreLocked => const DatabaseKeyUnavailable(
          DatabaseKeyProblem.locked,
        ),
        LegacyOwnerFailureCause.keyLost => const DatabaseKeyUnavailable(
          DatabaseKeyProblem.missing,
        ),
        LegacyOwnerFailureCause.contention => const DatabaseFileUnavailable(
          DatabaseFileProblem.contended,
        ),
        LegacyOwnerFailureCause.unsupportedSchema =>
          const DatabaseFileUnavailable(DatabaseFileProblem.schemaMismatch),
        LegacyOwnerFailureCause.unreadable => const DatabaseFileUnavailable(
          DatabaseFileProblem.unreadable,
        ),
        LegacyOwnerFailureCause.missingAfterAdmission =>
          const DatabaseFileUnavailable(DatabaseFileProblem.missing),
      },
      // A receipt this build cannot read says nothing about the file.
      LegacyImportVerificationFailed() => const DatabaseFileUnavailable(
        DatabaseFileProblem.inconsistent,
      ),
      _ => const DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
    };
