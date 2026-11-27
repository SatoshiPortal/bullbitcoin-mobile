import 'dart:async';
import 'dart:io';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:drift/drift.dart' show Value;
import 'package:legacy_storage/coordination.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/data.dart'
    show
        inventorySessionChangedFailure,
        inventoryCredentialRequiredFailure,
        inventoryLockedFailure,
        viewNotOpenFailure,
        viewInUseFailure,
        invalidBip85HexLengthFailure,
        unreadableBip85RecordFailure;

import '../data/access_repository.dart';
import '../data/ark_notify_policy.dart';
import '../data/backup_guard.dart';
import '../data/derivation_repository.dart';
import '../data/inventory_import.dart';
import '../data/inventory_repository.dart';
import '../data/inventory_session.dart';
import '../data/inventory_store.dart';
import '../data/ready_inventory_store.dart';
import '../data/view_administration_repository.dart';
export '../data/ready_inventory_store.dart' show inventoryReadinessFailure;
import '../data/secrets_database.drift.dart' show DerivationsCompanion;
import '../data/view_format.dart' show multiViewSupported;
import '../domain/access_attempt.dart';
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
part 'opened_views.dart';

/// The foreground wallet inventory. Access starts with the persisted policy.
/// Lock invalidates any pending read and the next operation checks the session.
final class SecretsInventory implements WalletInventory, SeedReferencePort {
  final InventoryStore _store;
  final AccessRepository _access;
  final InventoryRepository _wallets;
  final DerivationRepository _derivations;
  final BackupGuard _guard;
  final ViewAdministrationRepository _administration;
  final SessionAuthority _authority;
  var _session = 0;
  Future<void>? _pendingDrain;

  /// The views opened by the authentications of the live session. Empty while
  /// locked. [_epoch] changes at every lock, so an [OpenedViews] kept across a
  /// lock is refused even after a new unlock.
  var _openedViews = <ViewSummary>[];
  var _epoch = 0;

  SecretsInventory._(this._store, this._access, this._guard, this._authority)
    : _wallets = InventoryRepository(_store.database),
      _administration = ViewAdministrationRepository(_store.database, _guard),
      _derivations = DerivationRepository(_store.database) {
    _authority.bindMemberships(_seedsOf);
  }

  /// The seeds the token's view holds, or null while the file holds one view:
  /// an installation that shows a single view hides nothing from itself.
  Future<Set<String>?> _seedsOf(SessionToken token) async {
    try {
      final views = await _store.database
          .customSelect('SELECT COUNT(*) AS n FROM views')
          .getSingle();
      if (views.read<int>('n') <= 1) return null;
      return {
        for (final fingerprint in await viewSecrets(
          _store.database,
          token.activeView,
        ))
          fingerprint.hex,
      };
    } on Exception {
      // An unreadable membership hides every seed rather than showing all.
      return <String>{};
    }
  }

  bool get _unlocked => _authority.current != null;

  /// Open an existing, admitted inventory. A missing receipt blocks publication.
  ///
  /// [backupVerification] is the composition's one verifier, bound here before
  /// the capability exists. Without it the inventory refuses every decision that
  /// needs a backup proof; no operation lets a caller supply its own.
  ///
  /// [authority] is the session shared with `Secrets`. The inventory is the only
  /// writer: an authentication grants a token, locking revokes it.
  @useResult
  static Future<Result<SecretsInventory, DatabaseOpenFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    InventoryBackupVerification? backupVerification,
    required SessionAuthority authority,
    @visibleForTesting bool multiView = multiViewSupported,
  }) async {
    final opened = await openReadyInventoryStore(
      file,
      admission,
      multiView: multiView,
    );
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
            final inventory = SecretsInventory._(
              value,
              access,
              guard,
              authority,
            );
            if (protected) return Ok(inventory);
            // No view requires a credential: the session starts open.
            switch (await inventory._openWithoutCredential()) {
              case Ok():
                return Ok(inventory);
              case Err():
                await inventory.close();
                return const Err(
                  DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
                );
            }
        }
    }
  }

  @useResult
  Future<Result<bool, SecretFailure>> isProtected() => _access.isProtected();

  @useResult
  Future<Result<AccessAttempt, SecretFailure>> accessStatus() =>
      _access.status();

  /// Whether Ark may notify for [parent] while the app is locked: the rule of
  /// [ArkBackgroundAccess.mayNotify], asked in the foreground so an OS alarm is
  /// scheduled by the same rule there. It reads no seed and is not gated by
  /// the session: it answers a bool about the policy, never about a secret.
  @override
  @useResult
  Future<bool> mayNotifyArk(Fingerprint parent) =>
      arkNotifyPermitted(_store.database, parent);

  /// Whether no session may use secrets right now.
  bool get isLocked => !_unlocked;

  /// True on every lock, false on every unlock, in order.
  Stream<bool> get lockedChanges => _authority.changes.map((t) => t == null);

  /// Presents [candidate] to every credential at once and opens the views it
  /// unlocks. One guess is one attempt, whatever the number of credentials.
  /// The result names the views opened and nothing about the others.
  ///
  /// Authenticating inside a live session adds the views the credential opens
  /// and keeps the view in use and its handles. Only a locked inventory starts
  /// a session, on the first opened view by name.
  @useResult
  Future<Result<ViewAuthentication, SecretFailure>> authenticate(
    String candidate,
  ) async {
    if (_pendingDrain != null) return const Err(inventoryLockedFailure);
    final current = _session;
    final outcome = await _access.authenticate(candidate);
    if (current != _session || _pendingDrain != null) {
      return const Err(inventorySessionChangedFailure);
    }
    switch (outcome) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (!value.attempt.accepted) {
          return Ok(ViewAuthentication._(value.attempt, null));
        }
        final wasLocked = !_unlocked;
        // The remembered view is read before anything is published, so a
        // lock that lands meanwhile still wins.
        final chosen = wasLocked ? await _choose(value.opened) : null;
        if (current != _session || _pendingDrain != null) {
          return const Err(inventorySessionChangedFailure);
        }
        if (wasLocked) _epoch++;
        _mergeOpened(value.opened);
        final opened = OpenedViews._(this, _epoch);
        if (chosen != null) await _startSession(chosen);
        return Ok(ViewAuthentication._(value.attempt, opened));
    }
  }

  /// The flow of an installation that shows one view: authenticate, then open
  /// the view the session would start on.
  @useResult
  Future<Result<AccessAttempt, SecretFailure>> unlock(String candidate) async =>
      (await authenticate(candidate)).map((value) => value.attempt);

  void _mergeOpened(List<ViewSummary> add) {
    final byId = {for (final view in _openedViews) view.id: view};
    for (final view in add) {
      byId[view.id] = view;
    }
    _openedViews = List.unmodifiable(byId.values);
  }

  /// The view a session starts on among [opened] (never empty): the one
  /// opened last when this authentication opened it, otherwise the first by
  /// name. The memory is read only here, after an authentication, and a view
  /// this authentication did not open is never chosen.
  Future<ViewSummary> _choose(List<ViewSummary> opened) async {
    final remembered = await _access.lastView();
    return opened.firstWhere(
      (view) => view.id.value == remembered,
      orElse: () => opened.first,
    );
  }

  /// Opens the session on [view]: the grant is synchronous, so nothing can
  /// interleave between the checks that precede it and the token.
  Future<void> _startSession(ViewSummary view) {
    _authority.grant(view.id.value);
    return _access.rememberView(view.id.value);
  }

  Future<Result<void, SecretFailure>> _openWithoutCredential() async {
    final opened = await _access.openWithoutCredential();
    switch (opened) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Err(inventoryCredentialRequiredFailure);
      case Ok(:final value?):
        if (_unlocked) return const Ok(null);
        final current = _session;
        final chosen = await _choose(value);
        if (current != _session || _pendingDrain != null || _unlocked) {
          return const Err(inventorySessionChangedFailure);
        }
        _epoch++;
        _mergeOpened(value);
        await _startSession(chosen);
        return const Ok(null);
    }
  }

  /// Closes the inventory, in this order: the admission and the authority
  /// close first, so nothing new starts and no handle reaches key material;
  /// then work already admitted settles. A write that reaches its commit after
  /// the lock is rolled back; one already committed reports its true result.
  ///
  /// What survives a lock after its commit: a command that returns no value
  /// (a PIN change, a background grant, a wallet registration, removal or
  /// property change, a derivation rename or revocation) reports its true
  /// result, because the durable effect exists whatever the session did. It
  /// never publishes a projection of the old view. The one exception is a BIP85
  /// reservation (`reserveHexDerivation`, `reserveMnemonicDerivation`): it hands
  /// a value back and may be derived next, so after a lock it is refused even
  /// when its row committed; the reservation stays recorded and is never
  /// reused.
  ///
  /// Returns false if admitted work had not settled within [drain]. It then
  /// stays closed: the lock never reopens on a timeout, and the operation still
  /// running reports [inventorySessionChangedFailure] when it ends.
  Future<bool> lock({Duration drain = const Duration(seconds: 2)}) async {
    _session++;
    _epoch++;
    _openedViews = <ViewSummary>[];
    final pending = inventoryWritesSettled();
    _pendingDrain = pending;
    _authority.revoke();
    unawaited(
      pending.then((_) {
        if (identical(_pendingDrain, pending)) _pendingDrain = null;
      }),
    );
    try {
      await pending.timeout(drain);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  /// Waits for confirmed completion of any inventory writes admitted before
  /// locking, including when the bounded lock call already timed out.
  Future<void> waitForDrain() async {
    while (true) {
      final pending = _pendingDrain;
      if (pending == null) return;
      await pending;
    }
  }

  @useResult
  Future<Result<void, SecretFailure>> resumeUnprotected() {
    if (_pendingDrain != null) {
      return Future.value(const Err(inventoryLockedFailure));
    }
    return _inSession(requireUnlocked: false, (session, _) async {
      if (_pendingDrain != null) return const Err(inventoryLockedFailure);
      final result = await _openWithoutCredential();
      if (session != _session && _unlocked) return const Ok(null);
      return result;
    });
  }

  /// The secrets of the active view without a tested backup, by the same rule
  /// that protecting the view applies. Empty means the view can be protected;
  /// a view holding only watch-only wallets has no seed to prove (D95) and is
  /// still not backed up. Read only: [setCredential] decides again under the
  /// write lock.
  @useResult
  Future<Result<List<Fingerprint>, SecretFailure>> unbackedSecrets() =>
      _inSession((_, view) => _access.unbackedSecrets(view));

  /// Protect the active view, or replace its PIN, from an authenticated
  /// foreground session. Protecting needs a tested backup of every secret the
  /// view holds, judged by the verifier bound at composition.
  @useResult
  Future<Result<void, SecretFailure>> setCredential(String candidate) =>
      _inSession(
        (_, view) => _access.replaceCredential(candidate, view),
        preserveCommittedCommand: true,
      );

  /// Gives the active view a credential of its own with the PIN it already
  /// has, so rotating or removing either no longer moves the other. No effect
  /// on a view that does not share one.
  @useResult
  Future<Result<void, SecretFailure>> dissociateView() => _inSession(
    (_, view) => _access.dissociate(view),
    preserveCommittedCommand: true,
  );

  /// Remove access protection from an authenticated foreground session.
  @useResult
  Future<Result<void, SecretFailure>> removeCredential() => _inSession(
    (_, view) => _access.replaceCredential(null, view),
    preserveCommittedCommand: true,
  );

  /// Permit background sync to read the active view's descriptors while locked.
  @useResult
  Future<Result<void, SecretFailure>> setBackgroundEnabled(bool enabled) =>
      _inSession(
        (_, view) => _access.setBackgroundEnabled(enabled, view),
        preserveCommittedCommand: true,
      );

  @useResult
  Future<Result<List<RegisteredWallet>, SecretFailure>> listWallets() =>
      _inSession((_, view) => _wallets.list(view));

  @override
  @useResult
  Future<Result<List<Fingerprint>, SecretFailure>> referencedFingerprints() =>
      _inSession((_, view) => _wallets.referencedFingerprints(view));

  /// Whether the authorized view has any wallet, including on other networks.
  /// Seeds held by locally signing wallets of every view. A watch-only origin
  /// never keeps a seed alive (#2634); a locked session, an unreadable
  /// inventory or an invalid local reference cannot prove the seed unused.
  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async =>
      switch (await _inSession((_, _) => _wallets.custodyFingerprints())) {
        Ok(:final value) => Ok(value),
        Err() => const Err(SeedReferencesUnavailable()),
      };

  @useResult
  Future<Result<bool, SecretFailure>> hasWallets() async =>
      (await listWallets()).map((wallets) => wallets.isNotEmpty);

  /// Locally signing Bitcoin wallets and their public recovery evidence.
  @useResult
  Future<Result<List<BitcoinRecoveryWallet>, SecretFailure>>
  recoveryWallets() => _inSession((_, view) => _wallets.recoveryWallets(view));

  @useResult
  Future<Result<List<RegisteredWalletDescriptor>, SecretFailure>>
  listDescriptors() =>
      _inSession((_, view) => _wallets.descriptors(foregroundView: view));

  @useResult
  Future<Result<RegisteredWallet?, SecretFailure>> findWallet(String id) =>
      _inSession((_, view) => _wallets.find(view, id));

  @override
  @useResult
  Future<Result<WalletRegistration, SecretFailure>> readWallet(String id) =>
      _inSession((_, view) => _wallets.read(view, id));

  /// Publishes a joined read only while the session that started it is live.
  /// Exceptions from [read] propagate to the caller.
  @useResult
  Future<Result<T, SecretFailure>> readInSession<T>(
    Future<T> Function() read,
  ) => _inSession((_, _) async => Ok(await read()));

  @override
  @useResult
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) => _inSession((_, view) => _wallets.listForNetwork(view, network));

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
    (_, view) => _wallets.register(
      wallet,
      view: view,
      guard: _guard,
      prepareProperties: prepareProperties,
    ),
    preserveCommittedCommand: true,
  );

  @useResult
  Future<Result<void, SecretFailure>> setWalletProperties({
    required String id,
    required String? label,
    required DateTime? birthday,
    required bool isDefault,
  }) => _inSession(
    (_, view) => _wallets.updateProperties(
      view: view,
      id: id,
      label: label,
      birthday: birthday,
      isDefault: isDefault,
    ),
    preserveCommittedCommand: true,
  );

  @useResult
  Future<Result<void, SecretFailure>> removeWallet(String id) => _inSession(
    (_, view) => _wallets.remove(view: view, id: id),
    preserveCommittedCommand: true,
  );

  /// Operates on historical BIP85 children in the current foreground view.
  Bip85Derivations bip85(Secrets secrets) => Bip85Derivations._(this, secrets);

  @useResult
  Future<Result<List<RecordedDerivation>, SecretFailure>> listDerivations() =>
      _inSession((_, view) => _derivations.list(view));

  @useResult
  Future<Result<RecordedDerivation, SecretFailure>> reserveHexDerivation({
    required Fingerprint parent,
    required int length,
    String? alias,
  }) => _inSession(
    (_, view) => _derivations.reserveHex(
      view: view,
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
    (_, view) => _derivations.reserveMnemonic(
      view: view,
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
    (_, view) => _derivations.update(
      view: view,
      parentFingerprint: derivation.parentFingerprint,
      path: derivation.path,
      change: change,
    ),
    preserveCommittedCommand: true,
  );

  /// Runs [run] in the session now live, for the view that session opened. The
  /// view comes from the token, never from the caller: a view id supplied by a
  /// caller is not a right (D96).
  Future<Result<T, SecretFailure>> _inSession<T>(
    Future<Result<T, SecretFailure>> Function(int session, String view) run, {
    bool requireUnlocked = true,
    bool preserveCommittedCommand = false,
  }) async {
    final token = _authority.current;
    if (requireUnlocked && token == null) {
      return const Err(inventoryLockedFailure);
    }
    final session = _session;
    final view = token?.activeView ?? defaultViewId;
    return runInventorySession(
      () => run(session, view),
      isCurrent: () => session == _session,
      preserveCommittedCommand: preserveCommittedCommand,
    );
  }

  Future<void> close() async {
    await lock();
    await _store.close();
  }
}

/// The metadata backup client cannot fetch raw descriptors from this view.
extension MetadataBackupInventory on SecretsInventory {
  @useResult
  Future<Result<List<MetadataBackupWallet>, SecretFailure>>
  metadataBackupWallets(Secrets secrets) => _inSession((_, view) async {
    final projection = await _wallets.metadataBackupWallets(view);
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
    @visibleForTesting bool multiView = multiViewSupported,
  }) async => (await openReadyInventoryStore(
    file,
    admission,
    multiView: multiView,
  )).map(BackgroundWalletDescriptors._);

  @useResult
  Future<Result<List<RegisteredWalletDescriptor>, SecretFailure>> list() =>
      _wallets.descriptors();

  Future<void> close() => _store.close();
}
