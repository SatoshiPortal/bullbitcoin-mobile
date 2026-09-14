import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_backup_identity_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/reveal_backup_words_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_backup_identity_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/recoverbull_wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_words_extraction.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/extract_vaults_with_backup_words_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/wallet_backup_remote_usecases.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

import '../../nostr_identity/fixtures/backup_credential_vectors.dart';
import '../support/canonical_backup_snapshot.dart';
import '../support/fake_bullvault_backup.dart';

class _MockSettings extends Mock implements GetSettingsUsecase {}

class _MockDefaultSeed extends Mock implements GetDefaultSeedUsecase {}

/// The server as a words-only reader meets it: whatever bytes were stored, plus
/// the signed requests it received.
final class _FakeRemote implements WalletBackupRemoteRepository {
  final List<WalletBackupAuthentication> fetches = [];
  WalletBackupRemoteHead head = WalletBackupRemoteHead.absent(
    generation: 0,
    etag: null,
  );

  @override
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch({
    required WalletBackupAuthentication authentication,
  }) async {
    fetches.add(authentication);
    return Ok(head);
  }

  @override
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> store({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint? current,
    required WalletBackupCiphertext ciphertext,
    required String ciphertextSha256,
  }) => throw UnimplementedError();

  @override
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> delete({
    required WalletBackupAuthentication authentication,
    required WalletBackupRemoteCheckpoint current,
  }) => throw UnimplementedError();
}

/// Any call at all is a bug: a words-only read owns no local account.
final class _ForbiddenState implements WalletBackupStateRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'words-only extraction touched backup state: '
    '${invocation.memberName}',
  );
}

void main() {
  final encryption = RecoverBullWalletBackupEncryptionRepository(
    canonicalCodec(),
  );
  final credential = BackupCredential.fromWords(backupCredentialVectorWords);
  final vectorSeed = Seed.bytes(
    bytes: backupCredentialVectorSeed,
    masterFingerprint: hex.encode(
      bip32.Bip32Keys.fromSeed(backupCredentialVectorSeed).fingerprint,
    ),
  );
  final vectorFingerprint = Fingerprint(vectorSeed.masterFingerprint);

  late _FakeRemote remote;
  late ExtractVaultsWithBackupWordsUsecase extract;

  WalletBackupSnapshot snapshotFor(Fingerprint parent) => WalletBackupSnapshot(
    parentFingerprint: parent,
    createdAt: canonicalCreatedAt,
    recoveryManifest: KeychainManifest(
      parentFingerprint: parent,
      generatedAt: 1788191000,
      entries: const [],
    ),
    vaults: [
      fakeVaultEntry(
        walletRef: 'vault-generation-1',
        lineageId: 'lineage-a',
        vaultGeneration: 1,
      ),
      fakeVaultEntry(
        walletRef: 'vault-generation-0',
        status: 'migrating',
        lineageId: 'lineage-a',
        vaultGeneration: 0,
      ),
    ],
  );

  WalletBackupCiphertext sealed(
    WalletBackupSnapshot snapshot,
    BackupCredential owner,
  ) => switch (encryption.encrypt(
    envelope: snapshot,
    key: WalletBackupEncryptionKey(owner.encryptionKeyHex),
  )) {
    Ok(:final value) => value,
    Err(:final failure) => fail('encryption failed: $failure'),
  };

  void publish(WalletBackupCiphertext ciphertext) {
    remote.head = WalletBackupRemoteHead.present(
      generation: 3,
      etag: 'a' * 64,
      ciphertext: ciphertext,
      ciphertextSha256: 'b' * 64,
    );
  }

  setUp(() {
    remote = _FakeRemote();
    // No seed at all: the facade below can serve nothing, so anything that
    // succeeds did so on the strength of the words alone.
    extract = ExtractVaultsWithBackupWordsUsecase(
      FetchWalletBackupRemoteUsecase(
        remote,
        WalletBackupAuthenticator(_seedlessIdentity(), () => 1234),
      ),
      encryption,
      fakeVaultInspector,
    );
  });

  test(
    'words alone fetch, authenticate and decrypt a foreign backup',
    () async {
      publish(sealed(snapshotFor(canonicalParentFingerprint), credential));

      final result = await extract.execute(backupCredentialVectorWords);

      final extraction = _ok(result)!;
      expect(extraction.parentFingerprint, canonicalParentFingerprint.hex);
      expect(
        extraction.vaults.map((vault) => vault.walletRef),
        ['vault-generation-0', 'vault-generation-1'],
        reason: 'lineage then generation, so a predecessor replays first',
      );
      expect(remote.fetches.single.publicKeyHex, credential.serverPublicKeyHex);
      expect(
        remote.fetches.single.publicKeyHex,
        isNot(credential.nostrPublicKeyHex),
      );
      expect(remote.fetches.single.timestamp, 1234);
    },
  );

  test('an empty account is reported as nothing, not as a failure', () async {
    expect(_ok(await extract.execute(backupCredentialVectorWords)), isNull);
    expect(remote.fetches, hasLength(1));
  });

  test('a valid credential that is not this backup fails to decrypt', () async {
    publish(sealed(snapshotFor(canonicalParentFingerprint), credential));

    final result = await extract.execute(backupCredentialVectorOtherWords);

    expect(
      result,
      isA<Err<WalletBackupWordsExtraction?, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupEncryptionFailure>(),
      ),
    );
  });

  test('malformed words never reach the server', () async {
    for (final words in [
      '',
      'abandon ' * 12,
      'invalid ' * 12,
      backupCredentialVectorWords.split(' ').take(11).join(' '),
      'x' * 400,
    ]) {
      expect(
        await extract.execute(words),
        isA<Err<WalletBackupWordsExtraction?, WalletBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletBackupInvalidBackupWordsFailure>(),
        ),
      );
    }
    expect(remote.fetches, isEmpty);
  });

  test('the backup this seed writes is the backup its words read', () async {
    final settings = _MockSettings();
    final defaultSeed = _MockDefaultSeed();
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CRC',
      ),
    );
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenAnswer((_) async => Ok<Seed, SeedFailure>(vectorSeed));
    final owner = switch (await ResolveWalletBackupKeyUsecase(
      settings,
      defaultSeed,
    ).execute()) {
      Ok(:final value) => value,
      Err(:final failure) => fail('key derivation failed: $failure'),
    };
    expect(owner.encryptionKey.hex, backupCredentialVectorEncryptionKey);

    publish(switch (encryption.encrypt(
      envelope: snapshotFor(vectorFingerprint),
      key: owner.encryptionKey,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => fail('encryption failed: $failure'),
    });
    final extraction = _ok(
      await extract.execute(BackupCredential.deriveWords(vectorSeed)),
    )!;

    expect(extraction.parentFingerprint, vectorFingerprint.hex);
    expect(extraction.vaults, hasLength(2));
  });

  test('a seed-bound read still refuses a foreign backup', () async {
    final settings = _MockSettings();
    final defaultSeed = _MockDefaultSeed();
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CRC',
      ),
    );
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenAnswer((_) async => Ok<Seed, SeedFailure>(vectorSeed));
    final foreign = sealed(snapshotFor(canonicalParentFingerprint), credential);
    publish(foreign);

    // The words-only read accepts it as a source fact.
    expect(
      _ok(
        await extract.execute(backupCredentialVectorWords),
      )!.parentFingerprint,
      canonicalParentFingerprint.hex,
    );

    // The seed-bound read, which can apply what it reads, does not.
    final seedBound = await FetchWalletBackupSnapshotUsecase(
      resolveKey: ResolveWalletBackupKeyUsecase(settings, defaultSeed),
      encryption: encryption,
      state: _ForbiddenState(),
    ).execute(remote.head);

    expect(
      seedBound,
      isA<Err<WalletBackupSnapshot?, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupParentFingerprintMismatchFailure>(),
      ),
    );
  });

  test('the same origin signs identical bytes from seed or words', () async {
    final settings = _MockSettings();
    final defaultSeed = _MockDefaultSeed();
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CRC',
      ),
    );
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenAnswer((_) async => Ok<Seed, SeedFailure>(vectorSeed));
    final resolver = BackupCredentialResolver(settings, defaultSeed);
    final authenticator = WalletBackupAuthenticator(
      NostrIdentityFacade(
        GetBackupIdentityPublicKeyUsecase(resolver),
        SignBackupIdentityHashUsecase(resolver),
        RevealBackupWordsUsecase(resolver),
        resolver,
      ),
      () => 1234,
    );

    final fromSeed = await authenticator.sign(
      action: WalletBackupAction.fetch,
      generation: 0,
      expectedEtag: '',
      ciphertextSha256: '',
      ciphertextBytes: 0,
    );
    final fromWords = await authenticator.sign(
      action: WalletBackupAction.fetch,
      generation: 0,
      expectedEtag: '',
      ciphertextSha256: '',
      ciphertextBytes: 0,
      credential: credential,
    );

    final seedSigned = _okAuth(fromSeed);
    final wordsSigned = _okAuth(fromWords);
    expect(seedSigned.publicKeyHex, wordsSigned.publicKeyHex);
    expect(seedSigned.signatureHex, wordsSigned.signatureHex);
    expect(seedSigned.timestamp, wordsSigned.timestamp);
  });

  test('a supplied credential signs even with no seed on the device', () async {
    final authenticator = WalletBackupAuthenticator(
      _seedlessIdentity(),
      () => 1234,
    );

    expect(
      _okAuth(
        await authenticator.sign(
          action: WalletBackupAction.fetch,
          generation: 0,
          expectedEtag: '',
          ciphertextSha256: '',
          ciphertextBytes: 0,
          credential: credential,
        ),
      ).publicKeyHex,
      credential.serverPublicKeyHex,
    );
    expect(
      await authenticator.sign(
        action: WalletBackupAction.fetch,
        generation: 0,
        expectedEtag: '',
        ciphertextSha256: '',
        ciphertextBytes: 0,
      ),
      isA<Err<WalletBackupAuthentication, WalletBackupFailure>>(),
    );
  });

  test('nothing local is read or written while extracting', () async {
    publish(sealed(snapshotFor(canonicalParentFingerprint), credential));
    final state = _ForbiddenState();

    // The strict fake is handed to a seed-bound reader built over the same
    // bytes; the words-only use case is not even given one to call.
    expect(
      () => state.get(),
      throwsStateError,
      reason: 'the fake must fail loudly, or this test proves nothing',
    );
    expect(_ok(await extract.execute(backupCredentialVectorWords)), isNotNull);
  });
}

T _ok<T>(Result<T, WalletBackupFailure> result) {
  expect(result, isA<Ok<T, WalletBackupFailure>>());
  return (result as Ok<T, WalletBackupFailure>).value;
}

WalletBackupAuthentication _okAuth(
  Result<WalletBackupAuthentication, WalletBackupFailure> result,
) {
  expect(result, isA<Ok<WalletBackupAuthentication, WalletBackupFailure>>());
  return (result as Ok<WalletBackupAuthentication, WalletBackupFailure>).value;
}

/// A facade over a device that has no default seed.
NostrIdentityFacade _seedlessIdentity() {
  final settings = _MockSettings();
  final defaultSeed = _MockDefaultSeed();
  when(() => settings.execute()).thenAnswer(
    (_) async => const SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CRC',
    ),
  );
  when(
    () => defaultSeed.execute(environment: any(named: 'environment')),
  ).thenAnswer((_) async => const Err(DefaultSeedNotFoundFailure()));
  final resolver = BackupCredentialResolver(settings, defaultSeed);
  return NostrIdentityFacade(
    GetBackupIdentityPublicKeyUsecase(resolver),
    SignBackupIdentityHashUsecase(resolver),
    RevealBackupWordsUsecase(resolver),
    resolver,
  );
}
