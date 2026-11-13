import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:secrets/secrets.dart';
import '../../../nostr_identity/fixtures/backup_secret_fixture.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Identities extends Mock implements NostrIdentityFacade {}

class _Repository extends Fake implements NostrKeyRepository {
  final records = <NostrKeyRecord>[];
  KeychainManifestFailure? failure;

  @override
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>>
  getAll() async => switch (failure) {
    null => Ok(List.of(records)),
    final failure => Err(failure),
  };
  @override
  Future<Result<void, KeychainManifestFailure>> insert(
    NostrKeyRecord record,
  ) async {
    if (failure case final failure?) return Err(failure);
    records.add(record);
    return const Ok(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Identities identities;
  late _Repository repository;
  late Secret seed;
  final time = DateTime.utc(2026, 9, 18);
  Future<NostrKeyRecord> key(int identity) async => NostrKeyRecord(
    parentFingerprint: seed.id.hex,
    identity: identity,
    publicKey:
        (await seed.derive.nostrPublicKey(identity: identity)
                as Ok<String, SecretFailure>)
            .value,
    purpose: 'Existing',
    createdAt: time,
    updatedAt: time,
  );

  setUp(() async {
    seed = await backupSecretFixture();
    identities = _Identities();
    repository = _Repository();
    when(identities.defaultSecret).thenAnswer((_) async => Ok(seed));
  });

  test(
    'create uses the current environment and skips application identities after the durable maximum',
    () async {
      repository.records.add(await key(99));
      final result = await CreateNostrKeyUsecase(
        identities,
        repository,
      ).execute(purpose: ' Personal ', description: ' Notes ', now: time);
      final created =
          (result as Ok<NostrKeyRecord, KeychainManifestFailure>).value;
      expect(created.identity, 200);
      expect(created.purpose, 'Personal');
      expect(created.description, 'Notes');
      expect(
        repository.records.last.publicKey,
        (await seed.derive.nostrPublicKey(identity: 200)
                as Ok<String, SecretFailure>)
            .value,
      );
      verify(identities.defaultSecret).called(1);
    },
  );

  test(
    'failed inventory reads never restart allocation at identity one',
    () async {
      repository.failure = const KeychainManifestStorageFailure();
      expect(
        await CreateNostrKeyUsecase(
          identities,
          repository,
        ).execute(purpose: 'Personal'),
        isA<Err>(),
      );
      expect(repository.records, isEmpty);
    },
  );

  test('public listing works without asking the seed owner', () async {
    repository.records.add(await key(1));
    expect(
      (await GetNostrKeysUsecase(repository).execute() as Ok).value,
      hasLength(1),
    );
    verifyZeroInteractions(identities);
  });

  test('a missing seed does not allocate a public record', () async {
    when(
      identities.defaultSecret,
    ).thenAnswer((_) async => const Err(BackupCredentialUnavailable()));
    expect(
      await CreateNostrKeyUsecase(
        identities,
        repository,
      ).execute(purpose: 'Personal'),
      isA<Err<NostrKeyRecord, KeychainManifestFailure>>(),
    );
    expect(repository.records, isEmpty);
  });
}
