import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/backup_revision_recorder.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/entities/seed_derived_wallet_recovery_fact.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/remove_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/replace_seed_wallet_inventory_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_manifest_snapshot_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/update_passphrase_label_hint_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/watch_keychain_manifest_changes_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_nostr_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_nostr_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/recoverbull_wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_export_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/compare_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/decode_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_recovery_inventory_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/refresh_wallet_recovery_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/restore_wallet_backup_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_server_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/store_selected_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/register_wallet_backup_recovery_material_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/wallet_backup_remote_usecases.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/watch_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_job_runner.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_triggers.dart';
import 'package:async/async.dart' show StreamGroup;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../metadata/support/portable_settings_fixture.dart';

/// BIP39 test vector whose root is the default wallet in every backup suite.
const defaultSeedMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon about';
const defaultSeedFingerprint = '73c5da0a';

/// A second BIP39 test vector, used wherever a backup must belong to another
/// root than the one the harness is holding.
const foreignSeedMnemonic =
    'legal winner thank year wave sausage worth useful legal winner thank '
    'yellow';
const foreignSeedFingerprint = 'fedcba98';

WalletMetadataSnapshot emptyMetadataSnapshot() => WalletMetadataSnapshot(
  labels: const [],
  frozenOutpoints: const [],
  walletPreferences: const [],
  settings: portableSettingsFixture(),
);

Seed backupSeed({
  String mnemonic = defaultSeedMnemonic,
  String fingerprint = defaultSeedFingerprint,
}) => Seed.bytes(
  bytes: Uint8List.fromList(
    bip39.Mnemonic.fromSentence(mnemonic, bip39.Language.english).seed,
  ),
  masterFingerprint: fingerprint,
);

class _Settings extends Mock implements GetSettingsUsecase {}

class _DefaultSeed extends Mock implements GetDefaultSeedUsecase {}

/// In-memory stand-in for the backup server.
///
/// It keeps the parts of the wire contract the product depends on: one object
/// per account, a monotonic generation, an ETag that changes with the stored
/// bytes, and compare-and-swap rejection of a stale write.
final class FakeWalletBackupRemote implements WalletBackupRemoteRepository {
  WalletBackupCiphertext? _ciphertext;
  String? _ciphertextSha256;
  String? _etag;
  int _generation = 0;

  /// Injected transport faults. Set to simulate a rate-limited or unavailable
  /// server; clear to let the next attempt through.
  WalletBackupFailure? fetchFailure;
  WalletBackupFailure? storeFailure;

  int storeCount = 0;
  int storeAttempts = 0;
  int fetchCount = 0;

  /// Runs just before a store is applied, so a test can commit a local change
  /// while a publication is in flight.
  Future<void> Function()? beforeStore;

  String? get storedCiphertext => _ciphertext?.value;

  bool get isEmpty => _ciphertext == null;

  /// Publishes [ciphertext] as if another device had written it.
  void install(WalletBackupCiphertext ciphertext) {
    _ciphertext = ciphertext;
    _ciphertextSha256 = sha256
        .convert(base64.decode(ciphertext.value))
        .toString();
    _generation += 1;
    _etag = sha256
        .convert(utf8.encode('$_generation:$_ciphertextSha256'))
        .toString();
  }

  WalletBackupRemoteHead head() {
    final ciphertext = _ciphertext;
    if (ciphertext == null) {
      return WalletBackupRemoteHead.absent(
        generation: _generation,
        etag: _etag,
      );
    }
    return WalletBackupRemoteHead.present(
      generation: _generation,
      etag: _etag!,
      ciphertext: ciphertext,
      ciphertextSha256: _ciphertextSha256!,
    );
  }

  @override
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch({
    required WalletBackupAuthentication authentication,
  }) async {
    fetchCount += 1;
    final failure = fetchFailure;
    return failure == null ? Ok(head()) : Err(failure);
  }

  @override
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> store({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint? current,
    required WalletBackupCiphertext ciphertext,
    required String ciphertextSha256,
  }) async {
    storeAttempts += 1;
    await beforeStore?.call();
    final failure = storeFailure;
    if (failure != null) return Err(failure);
    if (!_matchesHead(current)) {
      return const Err(WalletBackupHeadConflictFailure());
    }
    storeCount += 1;
    install(ciphertext);
    return Ok(head().checkpoint!);
  }

  @override
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> delete({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint current,
  }) async {
    final failure = storeFailure;
    if (failure != null) return Err(failure);
    if (!_matchesHead(current)) {
      return const Err(WalletBackupHeadConflictFailure());
    }
    _ciphertext = null;
    _ciphertextSha256 = null;
    _generation += 1;
    _etag = sha256.convert(utf8.encode('$_generation:deleted')).toString();
    return Ok(head().checkpoint!);
  }

  bool _matchesHead(WalletBackupRemoteCheckpoint? current) =>
      (current?.generation ?? 0) == _generation && current?.etag == _etag;
}

/// External-wallet section stand-in. The harness leaves the section out of the
/// envelope unless a test sets [definitions].
final class FakeWalletDefinitionsSection implements WalletDefinitionsBackup {
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<WalletDefinition> definitions = const [];

  @override
  Stream<void> get changes => _changes.stream;

  void emitChange() => _changes.add(null);

  @override
  Future<Result<List<WalletDefinition>, WalletBackupFailure>> read() async =>
      Ok(definitions);

  @override
  Future<Result<WalletDefinitionsRecoveryResult, WalletBackupFailure>> recover({
    required List<WalletDefinition> definitions,
    DateTime? deadline,
  }) async => Ok(
    WalletDefinitionsRecoveryResult(
      restoredCount: 0,
      failedCount: 0,
      createdWalletRefs: const [],
    ),
  );

  Future<void> dispose() => _changes.close();
}

/// Protected-data section stand-in.
///
/// [snapshot] is the local snapshot the section would publish; changing it and
/// calling [emitChange] models the user editing labels or freezing a coin.
/// [recoverComplete] models a restore that could not finish.
final class FakeWalletMetadataSection {
  final StreamController<void> _changes = StreamController<void>.broadcast();

  WalletMetadataSnapshot snapshot = emptyMetadataSnapshot();
  bool recoverComplete = true;

  /// Thrown from [recover] to model a process that dies part-way through an
  /// apply, leaving the durable fence raised.
  Object? recoverError;
  final List<WalletMetadataSnapshot> recoveredSnapshots = [];

  Stream<void> get changes => _changes.stream;

  void emitChange() => _changes.add(null);

  Result<void, WalletMetadataBackupFailure> validate(
    WalletMetadataSnapshot snapshot,
  ) => const Ok(null);

  Future<Result<WalletMetadataSnapshot, WalletMetadataBackupFailure>>
  localSnapshot() async => Ok(snapshot);

  Future<Result<bool, WalletMetadataBackupFailure>> recover({
    required WalletMetadataSnapshot snapshot,
    required Set<String> createdWalletRefs,
    DateTime? deadline,
  }) async {
    if (recoverError case final error?) throw error;
    recoveredSnapshots.add(snapshot);
    return Ok(recoverComplete);
  }

  Future<void> dispose() => _changes.close();
}

/// One device: real state storage, real keychain manifest, real codecs and
/// real encryption, with the backup server and the two section owners faked.
///
/// Several harnesses can share one [FakeWalletBackupRemote] to model two
/// devices publishing to the same account.
final class WalletBackupBehaviorHarness {
  final SqliteDatabase database;
  final KeychainManifestRepositoryImpl manifestRepository;
  final KeychainManifestFacade keychainManifest;
  final WalletBackupJobRunner runner;
  final WalletBackupTriggers triggers;
  final WalletBackupFacade facade;
  final FakeWalletBackupRemote remote;
  final FakeWalletDefinitionsSection definitions;
  final FakeWalletMetadataSection metadata;
  final RecoverBullWalletBackupEncryptionRepository encryption;
  final String parentFingerprint;
  final WalletBackupEncryptionKey encryptionKey;
  final List<SeedDerivedWalletRecoveryFact> seedDerivedWallets;

  bool _started = false;
  bool _disposed = false;

  WalletBackupBehaviorHarness._({
    required this.database,
    required this.manifestRepository,
    required this.keychainManifest,
    required this.runner,
    required this.triggers,
    required this.facade,
    required this.remote,
    required this.definitions,
    required this.metadata,
    required this.encryption,
    required this.parentFingerprint,
    required this.encryptionKey,
    required this.seedDerivedWallets,
  });

  static Future<WalletBackupBehaviorHarness> create({
    Seed? seed,
    FakeWalletBackupRemote? remote,
    List<SeedDerivedWalletRecoveryFact> seedDerivedWallets = const [],
    SqliteDatabase? database,
    DateTime Function()? now,
  }) async {
    final walletSeed = seed ?? backupSeed();
    final settings = _Settings();
    final defaultSeed = _DefaultSeed();
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenAnswer((_) async => Ok<Seed, SeedFailure>(walletSeed));

    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final walletDatabase = database ?? SqliteDatabase(NativeDatabase.memory());
    final manifestRepository = KeychainManifestRepositoryImpl(
      walletDatabase,
      backupRevisions: DriftBackupRevisionRecorder(walletDatabase),
    );
    final keychainManifest = _manifestFacade(
      repository: manifestRepository,
      settings: settings,
      defaultSeed: defaultSeed,
    );
    final codec = WalletBackupSnapshotCodec(
      encodeManifest: keychainManifest.encodeManifestFilePayload,
      decodeManifest: keychainManifest.parseManifestFilePayload,
    );
    final encryption = RecoverBullWalletBackupEncryptionRepository(codec);
    final state = DriftWalletBackupStateRepository(walletDatabase);
    final backupRemote = remote ?? FakeWalletBackupRemote();
    final definitions = FakeWalletDefinitionsSection();
    final metadata = FakeWalletMetadataSection();

    final nostrIdentity = _nostrIdentity(settings, defaultSeed);
    final authenticator = WalletBackupAuthenticator(nostrIdentity);
    final fetchRemote = FetchWalletBackupRemoteUsecase(
      backupRemote,
      authenticator,
    );
    final storeRemote = StoreWalletBackupRemoteUsecase(
      backupRemote,
      authenticator,
    );
    final deleteRemote = DeleteWalletBackupRemoteUsecase(
      backupRemote,
      authenticator,
    );
    final resolveKey = ResolveWalletBackupKeyUsecase(settings, defaultSeed);
    final wallets = List<SeedDerivedWalletRecoveryFact>.of(seedDerivedWallets);
    final refreshManifest = RefreshWalletRecoveryManifestUsecase(
      () async => wallets,
      keychainManifest,
    );
    final buildSnapshot = BuildWalletBackupSnapshotUsecase(
      keychainManifest,
      definitions,
      metadata.localSnapshot,
    );
    final registerRecoveryMaterial =
        RegisterWalletBackupRecoveryMaterialUsecase(
          resolveKey,
          nostrIdentity,
          keychainManifest,
          refreshManifest,
        );
    final fetchImport = FetchWalletBackupSnapshotUsecase(
      resolveKey: resolveKey,
      encryption: encryption,
      state: state,
    );
    final publish = PublishWalletBackupUsecase(
      buildSnapshot: buildSnapshot,
      resolveKey: resolveKey,
      encryption: encryption,
      fetchRemote: fetchRemote,
      storeRemote: storeRemote,
      readRemoteSnapshot: fetchImport,
      state: state,
    );
    final publication = BackupWalletNowUsecase(
      state: state,
      publish: publish.execute,
      nowSecs: () => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    );
    final runner = WalletBackupJobRunner(
      publish: publication.execute,
      now: now,
    );
    final triggers = WalletBackupTriggers(
      recordedChanges: keychainManifest.watchCommittedChanges(),
      unrecordedChanges: _mergeChanges([definitions.changes, metadata.changes]),
      syncResults: const Stream.empty(),
      runner: runner,
      recordMutation: state.recordLocalMutation,
    );
    final applySnapshot = ApplyBackupSnapshotUsecase(
      state,
      definitions,
      restoreManifest: RestoreWalletBackupManifestUsecase(
        ({
          required walletId,
          required seedFingerprint,
          required network,
          required scriptType,
          required provenance,
          required derivationPath,
          required seedPassphraseUsed,
        }) async => true,
        keychainManifest,
      ),
      validateMetadata: metadata.validate,
      restoreMetadata: metadata.recover,
    );
    final decodeFile = DecodeWalletBackupFileUsecase(
      resolveKey.execute,
      encryption,
      nostrIdentity,
    );
    final recover = RecoverWalletBackupUsecase(
      fetchImport: fetchImport.execute,
      fetchRemote: fetchRemote.execute,
      apply: applySnapshot.execute,
    );
    final facade = WalletBackupFacade(
      GetWalletBackupContentsUsecase(
        GetWalletRecoveryInventoryUsecase(
          resolveKey.execute,
          refreshManifest.execute,
          keychainManifest.readManifest,
        ).execute,
        () async => const <WalletDefinition>[],
        () async => const <String>{},
        metadata.localSnapshot,
      ),
      WatchWalletBackupStateUsecase(state),
      SetWalletBackupEnabledUsecase(
        state,
        recover.execute,
        registerRecoveryMaterial.execute,
        publication.execute,
      ),
      SetWalletBackupServerUsecase(
        state,
        parseOrigin: parseWalletBackupServerOrigin,
      ),
      DeleteWalletBackupUsecase(
        fetchRemote: fetchRemote,
        deleteRemote: deleteRemote,
        state: state,
      ),
      runner,
      state,
      recover,
      BuildWalletBackupExportUsecase(
        buildSnapshot: buildSnapshot.execute,
        resolveKey: resolveKey.execute,
        encryption: encryption,
        identity: nostrIdentity,
      ),
      CompareWalletBackupFileUsecase(
        decodeFile.execute,
        state.get,
        fetchRemote.execute,
        fetchImport.execute,
        codec.differences,
      ),
      RecoverWalletBackupFileUsecase(
        decodeFile.execute,
        ({required snapshot, deadline}) => applySnapshot.execute(
          snapshot: snapshot,
          deadline: deadline,
          callerSettlesFence: true,
        ),
        applySnapshot.settle,
        state.get,
        fetchRemote.execute,
        StoreSelectedWalletBackupUsecase(
          resolveKey,
          encryption,
          storeRemote,
          state,
          () => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        ).execute,
      ),
    );

    final key = switch (await resolveKey.execute()) {
      Ok(:final value) => value,
      Err(:final failure) => fail('backup key derivation failed: $failure'),
    };

    return WalletBackupBehaviorHarness._(
      database: walletDatabase,
      manifestRepository: manifestRepository,
      keychainManifest: keychainManifest,
      runner: runner,
      triggers: triggers,
      facade: facade,
      remote: backupRemote,
      definitions: definitions,
      metadata: metadata,
      encryption: encryption,
      parentFingerprint: key.parentFingerprint,
      encryptionKey: key.encryptionKey,
      seedDerivedWallets: wallets,
    );
  }

  Fingerprint get fingerprint => Fingerprint(parentFingerprint);

  /// Starts the automatic publication triggers, as app start-up does.
  void startCoordinator() {
    if (_started) return;
    _started = true;
    triggers.start();
  }

  Future<WalletBackupState> readState() async =>
      switch (await facade.watchState().first) {
        Ok(:final value) => value,
        Err(:final failure) => fail('backup state unavailable: $failure'),
      };

  Future<void> dispose({bool closeDatabase = true}) async {
    if (_disposed) return;
    _disposed = true;
    await triggers.dispose();
    await runner.dispose();
    await definitions.dispose();
    await metadata.dispose();
    await manifestRepository.close();
    if (closeDatabase) await database.close();
  }
}

/// Pumps the event queue until [reached] holds, so tests can wait on work the
/// coordinator scheduled without reaching into its internals.
Future<void> settleUntil(
  Future<bool> Function() reached, {
  String description = 'expected state',
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (await reached()) return;
    await pumpEventQueue();
  }
  fail('timed out waiting for $description');
}

KeychainManifestFacade _manifestFacade({
  required KeychainManifestRepositoryImpl repository,
  required GetSettingsUsecase settings,
  required GetDefaultSeedUsecase defaultSeed,
}) {
  const codec = KeychainManifestFileCodec();
  final parse = ParseKeychainManifestFileUsecase(codec.decode);
  return KeychainManifestFacade(
    WatchKeychainManifestChangesUsecase(repository),
    codec.encode,
    BuildKeychainManifestFileUsecase(repository),
    parse,
    ReplaceSeedWalletInventoryUsecase(repository),
    RecordPassphraseWalletUsecase(repository),
    RestoreManifestSnapshotUsecase(repository),
    RecordKeychainManifestNostrKeyUsecase(repository),
    RestoreKeychainManifestNostrKeyUsecase(
      KeychainManifestNostrKeyDeriver(settings, defaultSeed),
      RecordKeychainManifestNostrKeyUsecase(repository),
    ),
    UpdatePassphraseLabelHintUsecase(repository),
    RemovePassphraseWalletUsecase(repository),
  );
}

NostrIdentityFacade _nostrIdentity(
  GetSettingsUsecase settings,
  GetDefaultSeedUsecase defaultSeed,
) {
  final resolver = NostrIdentityKeyResolver(settings, defaultSeed);
  return NostrIdentityFacade(
    GetNostrPublicKeyUsecase(resolver),
    SignNostrHashUsecase(resolver),
  );
}

Stream<void> _mergeChanges(List<Stream<void>> streams) =>
    StreamGroup.merge(streams);
