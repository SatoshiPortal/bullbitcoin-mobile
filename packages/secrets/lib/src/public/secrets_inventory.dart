import 'dart:io';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:drift/drift.dart' show Value;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart' show LegacyImportDeferred;
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
import '../data/derivation_repository.dart';
import '../data/inventory_import.dart';
import '../data/inventory_repository.dart';
import '../data/inventory_store.dart';
import '../data/secrets_database.drift.dart' show DerivationsCompanion;
import '../domain/access_attempt.dart';
import '../domain/domain.dart';
import '../domain/inventory_backup_verification.dart';
import '../domain/recorded_derivation.dart';
import '../domain/registered_wallet.dart';
import '../domain/wallet_registration.dart';
import 'extensions.dart';
import 'secret.dart';
import 'secrets.dart';
import 'wallet_inventory.dart';

part 'bip85_derivations.dart';

/// The foreground wallet inventory. Access starts with the persisted policy.
/// Lock invalidates any pending read and the next operation checks the session.
final class SecretsInventory implements WalletInventory {
  final InventoryStore _store;
  final AccessRepository _access;
  final InventoryRepository _wallets;
  final DerivationRepository _derivations;
  bool _unlocked;
  var _session = 0;

  SecretsInventory._(this._store, this._access, bool initiallyProtected)
    : _wallets = InventoryRepository(_store.database),
      _derivations = DerivationRepository(_store.database),
      _unlocked = !initiallyProtected;

  /// Open an existing, admitted inventory. A missing receipt blocks publication.
  @useResult
  static Future<Result<SecretsInventory, DatabaseOpenFailure>> open({
    required File file,
    required RuntimeAdmission admission,
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
          return Err(
            failure is LegacyImportDeferred
                ? const DatabaseKeyUnavailable(DatabaseKeyProblem.locked)
                : const DatabaseFileUnavailable(DatabaseFileProblem.unreadable),
          );
        }
        final access = AccessRepository(value.database);
        switch (await access.isProtected()) {
          case Err():
            await value.close();
            return const Err(
              DatabaseFileUnavailable(DatabaseFileProblem.unreadable),
            );
          case Ok(value: final protected):
            return Ok(SecretsInventory._(value, access, protected));
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

  @useResult
  Future<Result<bool, SecretFailure>> hasVerifiedBackups(
    InventoryBackupVerification verification,
  ) => _inSession((_) => _access.hasVerifiedBackups(verification));

  /// Protect the active view from an authenticated foreground session.
  @useResult
  Future<Result<void, SecretFailure>> setCredential(
    String candidate, {
    required InventoryBackupVerification backupVerification,
  }) => _inSession(
    (_) => _access.replaceCredential(
      candidate,
      backupVerification: backupVerification,
    ),
  );

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

  @override
  @useResult
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) => _inSession((_) => _wallets.listForNetwork(defaultViewId, network));

  /// Reserve the ID before preparing properties owned by other stores. The
  /// callback must not call back into this inventory. If it fails, the wallet
  /// and its membership are not published; a retry prepares its properties.
  @useResult
  Future<Result<void, SecretFailure>> registerWallet(
    RegisteredWallet wallet, {
    Future<Result<void, SecretFailure>> Function()? prepareProperties,
  }) => _inSession(
    (_) => _wallets.register(
      wallet,
      view: defaultViewId,
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

  Future<void> close() {
    lock();
    return _store.close();
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
      switch (await readInventoryReadiness(value.database)) {
        case Ok(value: OwnerReadiness.imported || OwnerReadiness.initialized):
          return result;
        case Ok():
          await value.close();
          return const Err(DatabaseNotReady());
        case Err():
          await value.close();
          return const Err(
            DatabaseFileUnavailable(DatabaseFileProblem.unreadable),
          );
      }
  }
}
