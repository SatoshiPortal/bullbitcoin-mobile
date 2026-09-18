import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _DefaultSeed extends Mock implements GetDefaultSeedUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

class _Repository extends Fake implements NostrKeyRepository {
  final records = <NostrKeyRecord>[];
  KeychainManifestFailure? failure;

  @override
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>>
  getAll() async => failure == null ? Ok(List.of(records)) : Err(failure!);
  @override
  Future<Result<void, KeychainManifestFailure>> insert(
    NostrKeyRecord record,
  ) async {
    if (failure != null) return Err(failure!);
    records.add(record);
    return const Ok(null);
  }
}

void main() {
  late _DefaultSeed defaults;
  late _Settings settings;
  late _Repository repository;
  final seed = Seed.bytes(
    bytes: Uint8List.fromList(List.filled(32, 99)),
    masterFingerprint: 'aabbccdd',
  );
  final time = DateTime.utc(2026, 9, 18);
  NostrKeyRecord key(int identity) => NostrKeyRecord(
    parentFingerprint: seed.masterFingerprint,
    identity: identity,
    publicKey: NostrKeyDeriver.publicKey(seed, identity),
    purpose: 'Existing',
    createdAt: time,
    updatedAt: time,
  );

  setUp(() {
    defaults = _DefaultSeed();
    settings = _Settings();
    repository = _Repository();
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => defaults.execute(environment: Environment.testnet),
    ).thenAnswer((_) async => seed);
  });

  test(
    'create uses the current environment and skips application identities after the durable maximum',
    () async {
      repository.records.add(key(99));
      final result = await CreateNostrKeyUsecase(
        defaults,
        settings,
        repository,
      ).execute(purpose: ' Personal ', description: ' Notes ', now: time);
      final created =
          (result as Ok<NostrKeyRecord, KeychainManifestFailure>).value;
      expect(created.identity, 200);
      expect(created.purpose, 'Personal');
      expect(created.description, 'Notes');
      expect(
        repository.records.last.publicKey,
        NostrKeyDeriver.publicKey(seed, 200),
      );
      verify(
        () => defaults.execute(environment: Environment.testnet),
      ).called(1);
    },
  );

  test(
    'failed inventory reads never restart allocation at identity one',
    () async {
      repository.failure = const KeychainManifestStorageFailure();
      expect(
        await CreateNostrKeyUsecase(
          defaults,
          settings,
          repository,
        ).execute(purpose: 'Personal'),
        isA<Err>(),
      );
      expect(repository.records, isEmpty);
    },
  );

  test('public listing works without asking the seed owner', () async {
    repository.records.add(key(1));
    expect(
      (await GetNostrKeysUsecase(repository).execute() as Ok).value,
      hasLength(1),
    );
    verifyZeroInteractions(defaults);
    verifyZeroInteractions(settings);
  });

  test(
    'private reveal verifies the record and does not retain key material between calls',
    () async {
      final reveal = RevealNostrKeyUsecase(defaults, settings);
      final success = await reveal.execute(key(1));
      expect(
        (success as Ok<RevealedNostrSecret, KeychainManifestFailure>)
            .value
            .nsec,
        startsWith('nsec1'),
      );
      expect(success.value.toString(), 'RevealedNostrSecret(<redacted>)');
      when(
        () => defaults.execute(environment: Environment.testnet),
      ).thenThrow(Exception('fixture locked'));
      expect(await reveal.execute(key(1)), isA<Err>());
    },
  );
}
