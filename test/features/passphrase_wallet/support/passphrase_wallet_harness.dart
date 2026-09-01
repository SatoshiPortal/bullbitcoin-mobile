import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/remove_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/replace_seed_wallet_inventory_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_manifest_snapshot_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/update_passphrase_label_hint_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/watch_keychain_manifest_changes_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_deriver.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_scanner.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;

const parentFingerprint = '73c5da0a';
const testMnemonic = ['abandon', 'about'];

// Real combined public descriptors in the canonical form the deriver produces
// and the record reader stores, so identity comparisons in tests fail for the
// same reasons they would fail in the app.
final firstDescriptor = _canonical(
  'wpkh([86241f88/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8Jfu'
  'DwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)',
);
final secondDescriptor = _canonical(
  'wpkh([a1b2c3d4/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8Jfu'
  'DwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)',
);

String _canonical(String descriptor) =>
    DescriptorDerivation.canonicalCombinedPublicBitcoinDescriptor(
      descriptor,
      Network.bitcoinMainnet,
    );

class _MockSettings extends Mock implements GetSettingsUsecase {}

class _MockDefaultSeed extends Mock implements GetDefaultSeedUsecase {}

/// The seed and settings owner contracts the passphrase use cases read through,
/// answering for one mainnet device with one active mnemonic (spec 6.1).
({GetDefaultSeedUsecase seed, GetSettingsUsecase settings})
fakeSeedAndSettings() {
  final settings = _MockSettings();
  final seed = _MockDefaultSeed();
  when(settings.execute).thenAnswer((_) async => fakeSettings);
  when(
    () => seed.execute(environment: any(named: 'environment')),
  ).thenAnswer((_) async => Ok(fakeParentSeed()));
  return (seed: seed, settings: settings);
}

/// A real manifest over an in-memory database, so the passphrase tests assert
/// against the manifest's own rules rather than a mock's idea of them.
///
/// [KeychainManifestFacade] is final by design, and the alternative — asserting
/// against a hand-written stand-in — is what lets a feature drift away from the
/// contract it actually runs against.
({KeychainManifestFacade facade, FaultInjectingManifestRepository repository})
buildManifest() {
  final database = SqliteDatabase(NativeDatabase.memory());
  final repository = FaultInjectingManifestRepository(
    KeychainManifestRepositoryImpl(database),
    database,
  );
  const codec = KeychainManifestFileCodec();
  return (
    facade: KeychainManifestFacade(
      WatchKeychainManifestChangesUsecase(repository),
      codec.encode,
      BuildKeychainManifestFileUsecase(repository),
      ParseKeychainManifestFileUsecase(codec.decode),
      ReplaceSeedWalletInventoryUsecase(repository),
      RecordPassphraseWalletUsecase(repository),
      RestoreManifestSnapshotUsecase(repository),
      RecordKeychainManifestNostrKeyUsecase(repository),
      RestoreKeychainManifestNostrKeyUsecase(
        KeychainManifestNostrKeyDeriver(_MockSettings(), _MockDefaultSeed()),
        RecordKeychainManifestNostrKeyUsecase(repository),
      ),
      UpdatePassphraseLabelHintUsecase(repository),
      RemovePassphraseWalletUsecase(repository),
    ),
    repository: repository,
  );
}

/// Delegates to a real manifest repository, and fails the writes a test asks it
/// to fail — the only way to reach the interrupted halves of Forget and of a
/// metadata edit (spec 25.9).
final class FaultInjectingManifestRepository
    implements KeychainManifestRepository {
  final KeychainManifestRepository _inner;
  final SqliteDatabase _database;

  var failRemove = false;
  var failLabelHint = false;
  var failUpsert = false;
  var failFetch = false;

  FaultInjectingManifestRepository(this._inner, this._database);

  Future<void> dispose() async {
    await _inner.close();
    await _database.close();
  }

  @override
  Future<Result<void, KeychainManifestFailure>> removePassphraseWallet({
    required Fingerprint parentFingerprint,
    required String walletId,
  }) async => failRemove
      ? const Err(KeychainManifestStorageFailure())
      : _inner.removePassphraseWallet(
          parentFingerprint: parentFingerprint,
          walletId: walletId,
        );

  @override
  Future<Result<void, KeychainManifestFailure>> updatePassphraseLabelHint({
    required Fingerprint parentFingerprint,
    required String walletId,
    KeychainManifestEdit<String?>? label,
    KeychainManifestEdit<String?>? hint,
    required int updatedAt,
  }) async => failLabelHint
      ? const Err(KeychainManifestStorageFailure())
      : _inner.updatePassphraseLabelHint(
          parentFingerprint: parentFingerprint,
          walletId: walletId,
          label: label,
          hint: hint,
          updatedAt: updatedAt,
        );

  @override
  Future<Result<void, KeychainManifestFailure>> upsertPassphraseWallet(
    KeychainManifestEntry record,
  ) async => failUpsert
      ? const Err(KeychainManifestStorageFailure())
      : _inner.upsertPassphraseWallet(record);

  @override
  Stream<void> watchLocalChanges() => _inner.watchLocalChanges();

  @override
  Future<Result<List<KeychainManifestEntry>, KeychainManifestFailure>> fetch(
    Fingerprint parentFingerprint,
  ) async => failFetch
      ? const Err(KeychainManifestStorageFailure())
      : _inner.fetch(parentFingerprint);

  @override
  Future<Result<void, KeychainManifestFailure>> replaceSeedWalletInventory(
    Fingerprint parentFingerprint,
    List<KeychainManifestEntry> entries,
  ) => _inner.replaceSeedWalletInventory(parentFingerprint, entries);

  @override
  Future<Result<KeychainManifestRestoreReport, KeychainManifestFailure>>
  restoreSnapshot(
    KeychainManifest manifest, {
    KeychainManifestRestorePolicy policy =
        KeychainManifestRestorePolicy.keepNewest,
  }) => _inner.restoreSnapshot(manifest, policy: policy);

  @override
  Future<Result<void, KeychainManifestFailure>> insertNostrKey(
    KeychainManifestEntry record, {
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  }) => _inner.insertNostrKey(record, origin: origin);

  @override
  Future<Result<void, KeychainManifestFailure>> updateNostrMetadata({
    required Fingerprint parentFingerprint,
    required String entryId,
    required String purpose,
    String? description,
    required int updatedAt,
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  }) => _inner.updateNostrMetadata(
    parentFingerprint: parentFingerprint,
    entryId: entryId,
    purpose: purpose,
    description: description,
    updatedAt: updatedAt,
    origin: origin,
  );

  @override
  Future<void> close() => _inner.close();
}

/// Records what the passphrase feature asked the wallet feature to do, in
/// order, so the ownership and forget-ordering rules can be asserted rather
/// than assumed.
final class FakeWalletFacade implements WalletFacade {
  final events = <String>[];
  final _catalog = StreamController<List<Wallet>>.broadcast();

  String? loadedWalletId;
  var _mountGeneration = 0;
  WalletDefinitionRestoreStatus mountStatus =
      WalletDefinitionRestoreStatus.created;
  Completer<void>? mountGate;
  Completer<void>? mountStarted;
  Exception? mountError;
  Exception? deleteError;
  Exception? labelError;

  void publishCatalog(List<String> visibleWalletIds) =>
      _catalog.add([for (final id in visibleWalletIds) fakeWallet(id)]);

  Future<void> dispose() => _catalog.close();

  @override
  int beginPassphraseWalletMount() => ++_mountGeneration;

  @override
  void cancelPassphraseWalletMount() => _mountGeneration++;

  @override
  Future<({WalletDefinitionRestoreResult result, bool capabilityLoaded})>
  mountPassphraseWallet({
    required WalletDefinition definition,
    required MnemonicSeed seed,
    required int mountGeneration,
    String? label,
  }) async {
    events.add('mount:${definition.walletRef}:$label');
    mountStarted?.complete();
    await mountGate?.future;
    final error = mountError;
    if (error != null) throw error;
    final loaded =
        mountGeneration == _mountGeneration &&
        mountStatus != WalletDefinitionRestoreStatus.conflict;
    if (loaded) {
      loadedWalletId = definition.walletRef;
    }
    return (
      result: WalletDefinitionRestoreResult(
        walletRef: definition.walletRef,
        status: mountStatus,
      ),
      capabilityLoaded: loaded,
    );
  }

  @override
  bool lockPrivateWalletSession() => _clear('lockForBackground');

  @override
  bool unloadPrivateWalletSession() => _clear('unload');

  @override
  bool takePendingLockNavigationRequest() => false;

  @override
  bool isPrivateWalletSessionLoaded(String walletId) =>
      loadedWalletId == walletId;

  @override
  Stream<List<Wallet>> watchVisibleWalletCatalog() => _catalog.stream;

  @override
  Future<void> deletePublicProjection(String walletId) async {
    events.add('deleteProjection:$walletId');
    final error = deleteError;
    if (error != null) throw error;
    if (loadedWalletId == walletId) loadedWalletId = null;
  }

  @override
  Future<void> updateWalletLabel({
    required String walletId,
    required String label,
  }) async {
    events.add('updateLabel:$walletId:$label');
    final error = labelError;
    if (error != null) throw error;
  }

  bool _clear(String event) {
    events.add(event);
    final wasLoaded = loadedWalletId != null;
    loadedWalletId = null;
    return wasLoaded;
  }
}

final class FakePassphraseWalletDeriver implements PassphraseWalletDeriver {
  /// Passphrase to the wallet it derives. Anything else derives a wallet the
  /// app has never seen.
  final Map<String, ({String walletId, String descriptor})> wallets;
  Exception? error;
  Completer<void>? gate;
  final derived = <String>[];

  /// The exact material handed out per passphrase, so a test can assert the
  /// bytes that were derived are the bytes that got zeroed.
  final issued = <String, MnemonicSeed>{};

  FakePassphraseWalletDeriver([
    Map<String, ({String walletId, String descriptor})> wallets = const {},
  ]) : wallets = {...wallets};

  @override
  Future<PassphraseWalletDerivation> derive({
    required MnemonicSeed parentSeed,
    required String passphrase,
    required Network network,
  }) async {
    derived.add(passphrase);
    await gate?.future;
    final error = this.error;
    if (error != null) throw error;
    final known = wallets[passphrase];
    final seed = fakeSeed(passphrase);
    issued[passphrase] = seed;
    return PassphraseWalletDerivation(
      walletId: known?.walletId ?? 'wallet-for-$passphrase',
      combinedPublicDescriptor: known?.descriptor ?? 'descriptor-$passphrase',
      seed: seed,
    );
  }
}

final class FakePassphraseWalletScanner implements PassphraseWalletScanner {
  final scanned = <String>[];
  final Map<String, BigInt> balances;
  final failing = <String>{};
  Completer<void>? gate;

  FakePassphraseWalletScanner({this.balances = const {}});

  @override
  Future<BigInt> scan({
    required String combinedPublicDescriptor,
    required Network network,
  }) async {
    scanned.add(combinedPublicDescriptor);
    await gate?.future;
    if (failing.contains(combinedPublicDescriptor)) {
      throw const PassphraseWalletScanException();
    }
    return balances[combinedPublicDescriptor] ?? BigInt.zero;
  }
}

/// The app's active mnemonic, the one every passphrase wallet derives from.
MnemonicSeed fakeParentSeed() =>
    Seed.mnemonic(
          mnemonicWords: testMnemonic,
          bytes: Uint8List.fromList(List.filled(8, 9)),
          masterFingerprint: parentFingerprint,
        )
        as MnemonicSeed;

MnemonicSeed fakeSeed(String passphrase, {int fill = 1}) =>
    Seed.mnemonic(
          mnemonicWords: testMnemonic,
          passphrase: passphrase,
          bytes: Uint8List.fromList(List.filled(8, fill)),
          masterFingerprint: '01234567',
        )
        as MnemonicSeed;

/// One passphrase wallet as the manifest takes it.
KeychainManifestWalletInventoryBinding passphraseBinding({
  String walletId = 'wallet',
  String? descriptor,
  String? label,
  String? hint,
  int createdAt = 1,
}) => KeychainManifestWalletInventoryBinding(
  walletId: walletId,
  // Distinct per wallet: the entry a record lands in is keyed by it, so sharing
  // one would make a second wallet look like a conflicting rewrite of the first.
  seedFingerprint: Fingerprint(
    walletId.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0'),
  ),
  network: Network.bitcoinMainnet,
  scriptType: ScriptType.bip84,
  provenance: WalletProvenance.defaultSeedPassphrase,
  derivationPath: "m/84'/0'/0'",
  seedPassphraseUsed: true,
  descriptor: descriptor ?? firstDescriptor,
  label: label,
  description: hint,
  createdAt: createdAt,
  updatedAt: createdAt,
);

PassphraseWalletRecord fakeRecord({
  String walletId = 'wallet',
  String? descriptor,
  String? label,
  String? hint,
  DateTime? createdAt,
}) => PassphraseWalletRecord(
  walletId: walletId,
  parentFingerprint: Fingerprint(parentFingerprint),
  seedFingerprint: Fingerprint('01234567'),
  network: Network.bitcoinMainnet,
  descriptor: descriptor ?? firstDescriptor,
  createdAt: createdAt ?? DateTime.utc(2026),
  label: label,
  hint: hint,
);

PassphraseWalletPreparation fakePreparation({
  PassphraseWalletRecord? known,
  bool hasHistory = false,
  String passphrase = 'secret',
  PassphraseWalletRecord? record,
}) => PassphraseWalletPreparation(
  candidate: PassphraseWalletCandidate(
    record: record ?? known ?? fakeRecord(),
    seed: fakeSeed(passphrase),
  ),
  knownWallet: known,
  hasHistory: hasHistory,
);

Wallet fakeWallet(String id) => Wallet(
  origin: id,
  network: Network.bitcoinMainnet,
  xpubFingerprint: 'deadbeef',
  scriptType: ScriptType.bip84,
  xpub: 'xpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

const fakeSettings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'CAD',
);
