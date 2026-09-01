import 'dart:convert';
import 'dart:typed_data';

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
import 'package:bb_mobile/features/nostr_identity/domain/get_nostr_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_nostr_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
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
    required String expectedParentFingerprint,
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
    required String expectedParentFingerprint,
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
const _expectedEncryptionKey =
    '321154f080538350e83f2ebf866595a778ab671e55aacfe0638305ba95a48830';

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

  test('derives the frozen backup key from the reserved BIP85 path', () async {
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
    final identity = _nostrIdentity(settings, defaultSeed);
    final definitions = _DefinitionsBackup();
    expect(
      await RegisterWalletBackupRecoveryMaterialUsecase(
        ResolveWalletBackupKeyUsecase(settings, defaultSeed),
        identity,
        manifest,
        RefreshWalletRecoveryManifestUsecase(() async => const [], manifest),
      ).execute(),
      isA<Ok<void, WalletBackupFailure>>(),
    );

    final result = await BuildWalletBackupSnapshotUsecase(
      manifest,
      definitions,
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
    final entries = snapshot.recoveryManifest.entries;
    expect(entries, hasLength(1));
    expect(entries.single.derivationPath, "128002'/100'/1'");
    expect(
      entries.map((entry) => entry.derivationPath),
      isNot(contains("128002'/101'/1'")),
    );
    expect(
      entries.map((entry) => entry.derivationPath),
      isNot(contains("128002'/102'/1'")),
    );
    final materialization =
        entries.single.materializations.single as KeychainManifestNostrKey;
    expect(materialization.keyKind, KeychainManifestNostrKeyKind.reserved);
    expect(materialization.purpose, 'Wallet backup');
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
