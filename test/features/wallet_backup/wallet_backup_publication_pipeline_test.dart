import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/remove_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/replace_seed_wallet_inventory_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_manifest_snapshot_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/watch_keychain_manifest_changes_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/update_passphrase_label_hint_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_backup_identity_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_backup_identity_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_vaults_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/refresh_wallet_recovery_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/register_wallet_backup_recovery_material_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/wallet_backup_remote_usecases.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import 'metadata/support/portable_settings_fixture.dart';
import 'support/fake_bullvault_backup.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class _Settings extends Mock implements GetSettingsUsecase {}

class _DefaultSeed extends Mock implements GetDefaultSeedUsecase {}

class _ManifestRepository extends Mock implements KeychainManifestRepository {}

Future<Result<WalletMetadataSnapshot, WalletMetadataBackupFailure>>
_readMetadata() async => Ok(metadataSnapshot);

final class _DefinitionsBackup implements WalletDefinitionsBackup {
  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<Result<List<WalletDefinition>, WalletBackupFailure>> read() async =>
      const Ok([]);

  @override
  Future<Result<WalletDefinitionsRecoveryResult, WalletBackupFailure>> recover({
    required List<WalletDefinition> definitions,
    DateTime? deadline,
  }) => throw UnimplementedError();
}

/// Definitions the snapshot builder sees; one of them belongs to a vault.
final class _OwnedDefinitionsBackup extends _DefinitionsBackup {
  @override
  Future<Result<List<WalletDefinition>, WalletBackupFailure>> read() async =>
      Ok([
        WalletDefinition(
          walletRef: 'vault-wallet',
          network: Network.bitcoinMainnet,
          descriptor: 'tr(vault)',
          provenance: WalletProvenance.descriptor,
        ),
        WalletDefinition(
          walletRef: 'cold-wallet',
          network: Network.bitcoinMainnet,
          descriptor: 'wpkh(cold)',
          provenance: WalletProvenance.watchOnly,
        ),
      ]);
}

/// Only the two operations the publication path uses are exercised here.
final class _StateRepository extends Mock
    implements WalletBackupStateRepository {}

final class _EncryptionRepository implements WalletBackupEncryptionRepository {
  final WalletBackupCiphertext ciphertext;
  WalletBackupSnapshot? encryptedEnvelope;
  WalletBackupEncryptionKey? encryptionKey;

  _EncryptionRepository(this.ciphertext);

  @override
  Result<Uint8List, WalletBackupFailure> encodeCanonical(
    WalletBackupSnapshot envelope,
  ) => throw UnimplementedError();

  @override
  Result<WalletBackupSnapshot, WalletBackupFailure> decodeCanonical({
    required Uint8List bytes,
    required String? expectedParentFingerprint,
  }) => throw UnimplementedError();

  @override
  Result<WalletBackupCiphertext, WalletBackupFailure> encrypt({
    required WalletBackupSnapshot envelope,
    required WalletBackupEncryptionKey key,
  }) {
    encryptedEnvelope = envelope;
    encryptionKey = key;
    return Ok(ciphertext);
  }

  @override
  Result<WalletBackupSnapshot, WalletBackupFailure> decrypt({
    required WalletBackupCiphertext ciphertext,
    required WalletBackupEncryptionKey key,
    required String? expectedParentFingerprint,
  }) => throw UnimplementedError();
}

final class _RemoteRepository implements WalletBackupRemoteRepository {
  final WalletBackupRemoteHead head = WalletBackupRemoteHead.absent(
    generation: 0,
    etag: null,
  );
  final List<WalletBackupAuthentication> fetchAuthentications = [];
  WalletBackupAuthentication? storeAuthentication;
  WalletBackupRemoteCheckpoint? storedAgainst;
  WalletBackupCiphertext? storedCiphertext;
  String? storedCiphertextSha256;

  @override
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch({
    required WalletBackupAuthentication authentication,
  }) async {
    fetchAuthentications.add(authentication);
    return Ok(head);
  }

  @override
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> store({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint? current,
    required WalletBackupCiphertext ciphertext,
    required String ciphertextSha256,
  }) async {
    storeAuthentication = authentication;
    storedAgainst = current;
    storedCiphertext = ciphertext;
    storedCiphertextSha256 = ciphertextSha256;
    return Ok(
      WalletBackupRemoteCheckpoint(
        generation: (current?.generation ?? 0) + 1,
        etag: 'e' * 64,
        ciphertextSha256: ciphertextSha256,
      ),
    );
  }

  @override
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> delete({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint current,
  }) => throw UnimplementedError();
}

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _fingerprint = '73c5da0a';
final metadataSnapshot = WalletMetadataSnapshot(
  labels: const [],
  frozenOutpoints: const [],
  walletPreferences: const [],
  settings: portableSettingsFixture(),
);
// The key the twelve words derive, reproduced independently in Python.
const _expectedEncryptionKey =
    'f282cd95c7252487a8dfcee00c5992ca3be78b1dc08adc24fb1dd75c3d10bdf6';
const _expectedServerPublicKey =
    'b83e4c3ce576c3d5c98d35549fc4e63912ddade166bfed36fc9d913e0ecb1732';
const _expectedArtifactPublicKey =
    '5aaf0e2e3052791f7ad96eaf656e7f7cd94ee3039522407d48e5decf0beec6a9';

void main() {
  late Seed seed;
  late _Settings settings;
  late _DefaultSeed defaultSeed;
  late _ManifestRepository manifestRepository;
  late List<KeychainManifestEntry> manifestEntries;
  late KeychainManifestFacade manifest;

  setUpAll(() {
    registerFallbackValue(Fingerprint('00000000'));
    registerFallbackValue(KeychainManifestWriteOrigin.local);
    registerFallbackValue(<KeychainManifestEntry>[]);
    registerFallbackValue(_fallbackManifestEntry());
    seed = Seed.bytes(
      bytes: Uint8List.fromList(
        bip39.Mnemonic.fromSentence(_mnemonic, bip39.Language.english).seed,
      ),
      masterFingerprint: _fingerprint,
    );
  });

  setUp(() {
    settings = _Settings();
    defaultSeed = _DefaultSeed();
    manifestRepository = _ManifestRepository();
    manifestEntries = [];
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CRC',
      ),
    );
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenAnswer((_) async => Ok<Seed, SeedFailure>(seed));
    when(
      () => manifestRepository.fetch(Fingerprint(_fingerprint)),
    ).thenAnswer((_) async => Ok(List.unmodifiable(manifestEntries)));
    when(
      () => manifestRepository.insertNostrKey(
        any(),
        origin: any(named: 'origin'),
      ),
    ).thenAnswer((invocation) async {
      manifestEntries = [
        ...manifestEntries,
        invocation.positionalArguments.single as KeychainManifestEntry,
      ];
      return const Ok(null);
    });
    when(
      () => manifestRepository.replaceSeedWalletInventory(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    manifest = _manifestFacade(
      repository: manifestRepository,
      settings: settings,
      defaultSeed: defaultSeed,
    );
  });

  test('derives the frozen backup key from the twelve words', () async {
    final result = await ResolveWalletBackupKeyUsecase(
      settings,
      defaultSeed,
    ).execute();

    expect(result, isA<Ok<WalletBackupKey, WalletBackupFailure>>());
    final key = (result as Ok<WalletBackupKey, WalletBackupFailure>).value;
    expect(key.parentFingerprint, _fingerprint);
    expect(key.encryptionKey.hex, _expectedEncryptionKey);
  });

  test('reports an unavailable wallet without deriving a key', () async {
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenAnswer((_) async => const Err(DefaultSeedNotFoundFailure()));

    expect(
      await ResolveWalletBackupKeyUsecase(settings, defaultSeed).execute(),
      isA<Err<WalletBackupKey, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupWalletUnavailableFailure>(),
      ),
    );
  });

  test('builds one snapshot from the manifest and metadata sections', () async {
    final definitions = _DefinitionsBackup();
    expect(
      await RegisterWalletBackupRecoveryMaterialUsecase(
        ResolveWalletBackupKeyUsecase(settings, defaultSeed),
        RefreshWalletRecoveryManifestUsecase(() async => const [], manifest),
      ).execute(),
      isA<Ok<void, WalletBackupFailure>>(),
    );

    final result = await BuildWalletBackupSnapshotUsecase(
      manifest,
      definitions,
      FakeBullVaultBackupSection(),
      _readMetadata,
      nowUtc: () => DateTime.fromMillisecondsSinceEpoch(42000, isUtc: true),
    ).execute(parentFingerprint: _fingerprint, allowEmpty: true);

    expect(result, isA<Ok<WalletBackupSnapshot, WalletBackupFailure>>());
    final snapshot =
        (result as Ok<WalletBackupSnapshot, WalletBackupFailure>).value;
    expect(snapshot.parentFingerprint.hex, _fingerprint);
    expect(snapshot.createdAt, 42);
    expect(snapshot.metadata, same(metadataSnapshot));
    expect(snapshot.externalWalletDefinitions, isEmpty);
    expect(snapshot.recoveryManifest.parentFingerprint.hex, _fingerprint);
    // The backup identity comes from the twelve words, not from a BIP85 path,
    // so registering recovery material records no reserved key at all.
    expect(snapshot.recoveryManifest.entries, isEmpty);
    for (final reserved in [
      Bip85Reservations.retiredWalletBackupNostrKeyPath,
      "1642'/0'/1'",
      "128002'/101'/1'",
      "128002'/102'/1'",
    ]) {
      expect(
        snapshot.recoveryManifest.entries.map((entry) => entry.derivationPath),
        isNot(contains(reserved)),
      );
    }
  });

  test("a vault's wallet is carried by the vaults section only", () async {
    final vaults = FakeBullVaultBackupSection()
      ..entries = [fakeVaultEntry(walletRef: 'vault-wallet')];

    final result = await BuildWalletBackupSnapshotUsecase(
      manifest,
      _OwnedDefinitionsBackup(),
      vaults,
      _readMetadata,
      nowUtc: () => DateTime.fromMillisecondsSinceEpoch(42000, isUtc: true),
    ).execute(parentFingerprint: _fingerprint, allowEmpty: true);

    final snapshot =
        (result as Ok<WalletBackupSnapshot, WalletBackupFailure>).value;
    expect(
      snapshot.externalWalletDefinitions.map(
        (definition) => definition.walletRef,
      ),
      ['cold-wallet'],
    );
    expect(snapshot.vaults.map((vault) => vault.walletRef), ['vault-wallet']);
  });
  test('stores an authenticated backup when the remote is absent', () async {
    final harness = _publication(settings, defaultSeed, manifest);

    final result = await harness.publish.execute(null);

    expect(
      result,
      isA<Ok<WalletBackupRemoteCheckpoint, WalletBackupFailure>>(),
    );
    expect(harness.remote.fetchAuthentications, hasLength(1));
    expect(harness.remote.fetchAuthentications.single.timestamp, 1234);
    expect(harness.remote.storeAuthentication?.timestamp, 1234);
    expect(
      harness.remote.storeAuthentication?.publicKeyHex,
      harness.remote.fetchAuthentications.single.publicKeyHex,
    );
    expect(
      harness.remote.storeAuthentication?.publicKeyHex,
      _expectedServerPublicKey,
    );
    expect(
      harness.remote.storeAuthentication?.publicKeyHex,
      isNot(_expectedArtifactPublicKey),
      reason: 'the account is never named by the public artifact author',
    );
    expect(harness.remote.storeAuthentication?.signatureHex, isNot(isEmpty));
    expect(harness.remote.storedAgainst, isNull);
    expect(harness.remote.storedCiphertext, same(harness.ciphertext));
    expect(
      harness.remote.storedCiphertextSha256,
      sha256.convert(base64.decode(harness.ciphertext.value)).toString(),
    );
    expect(
      harness.encryption.encryptedEnvelope?.metadata,
      same(metadataSnapshot),
    );
    expect(harness.encryption.encryptionKey?.hex, _expectedEncryptionKey);
  });

  test('a trusted checkpoint publishes without fetching the head', () async {
    final harness = _publication(settings, defaultSeed, manifest);
    final checkpoint = WalletBackupRemoteCheckpoint(
      generation: 5,
      etag: 'f' * 64,
      ciphertextSha256: 'a' * 64,
    );

    final result = await harness.publish.execute(checkpoint);

    expect(
      result,
      isA<Ok<WalletBackupRemoteCheckpoint, WalletBackupFailure>>().having(
        (value) => value.value.generation,
        'acknowledged generation',
        6,
      ),
    );
    expect(harness.remote.fetchAuthentications, isEmpty);
    expect(harness.remote.storedAgainst, same(checkpoint));
  });
}

final class _PublicationHarness {
  final PublishWalletBackupUsecase publish;
  final _RemoteRepository remote;
  final _EncryptionRepository encryption;
  final WalletBackupCiphertext ciphertext;

  const _PublicationHarness({
    required this.publish,
    required this.remote,
    required this.encryption,
    required this.ciphertext,
  });
}

_PublicationHarness _publication(
  GetSettingsUsecase settings,
  GetDefaultSeedUsecase defaultSeed,
  KeychainManifestFacade manifest,
) {
  final ciphertext = WalletBackupCiphertext(
    base64.encode(List<int>.generate(64, (index) => index)),
  );
  final encryption = _EncryptionRepository(ciphertext);
  final remote = _RemoteRepository();
  final identity = _nostrIdentity(settings, defaultSeed);
  final authenticator = WalletBackupAuthenticator(identity, () => 1234);
  final resolveKey = ResolveWalletBackupKeyUsecase(settings, defaultSeed);
  final state = _StateRepository();
  return _PublicationHarness(
    publish: PublishWalletBackupUsecase(
      buildSnapshot: BuildWalletBackupSnapshotUsecase(
        manifest,
        _DefinitionsBackup(),
        FakeBullVaultBackupSection(),
        _readMetadata,
        nowUtc: () => DateTime.fromMillisecondsSinceEpoch(42000, isUtc: true),
      ),
      resolveKey: resolveKey,
      encryption: encryption,
      fetchRemote: FetchWalletBackupRemoteUsecase(remote, authenticator),
      storeRemote: StoreWalletBackupRemoteUsecase(remote, authenticator),
      readRemoteSnapshot: FetchWalletBackupSnapshotUsecase(
        resolveKey: resolveKey,
        encryption: encryption,
        state: state,
      ),
      state: state,
      differences: WalletBackupSnapshotCodec(
        encodeManifest: manifest.encodeManifestFilePayload,
        decodeManifest: manifest.parseManifestFilePayload,
        vaults: const WalletBackupVaultsCodec(inspect: fakeVaultInspector),
      ).differences,
    ),
    remote: remote,
    encryption: encryption,
    ciphertext: ciphertext,
  );
}

KeychainManifestFacade _manifestFacade({
  required KeychainManifestRepository repository,
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
  final resolver = BackupCredentialResolver(settings, defaultSeed);
  return NostrIdentityFacade(
    GetBackupIdentityPublicKeyUsecase(resolver),
    SignBackupIdentityHashUsecase(resolver),
    resolver,
  );
}

KeychainManifestEntry _fallbackManifestEntry() => KeychainManifestEntry(
  parentFingerprint: Fingerprint(_fingerprint),
  derivationPath: "128002'/0'/0'",
  createdAt: 1,
  updatedAt: 1,
  materializations: [
    KeychainManifestNostrKey(
      entryId: "$_fingerprint:128002'/0'/0'",
      publicKeyHex: '1' * 64,
      keyKind: KeychainManifestNostrKeyKind.userGenerated,
      purpose: 'Fallback',
      createdAt: 1,
      updatedAt: 1,
    ),
  ],
);
