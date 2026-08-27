import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_keychain_manifest_reservation_wallet_ids_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/merge_keychain_manifest_file_payloads_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_reserved_wallets_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/update_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/watch_keychain_manifest_changes_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok;
import 'package:mocktail/mocktail.dart';

import 'support/manifest_fixtures.dart';

void main() {
  late SqliteDatabase database;
  late KeychainManifestRepositoryImpl repository;
  late KeychainManifestFacade facade;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    repository = KeychainManifestRepositoryImpl(database);
    const codec = KeychainManifestFileCodec();
    const parse = ParseKeychainManifestFileUsecase(codec);
    facade = KeychainManifestFacade(
      WatchKeychainManifestChangesUsecase(repository),
      codec,
      BuildKeychainManifestFileUsecase(repository),
      parse,
      const MergeKeychainManifestFilePayloadsUsecase(codec, parse),
      RecordReservedWalletsUsecase(repository),
      RecordKeychainManifestNostrKeyUsecase(repository),
      GetKeychainManifestReservationWalletIdsUsecase(repository),
      KeychainManifestNostrKeyDeriver(
        _MockGetSettingsUsecase(),
        _MockGetDefaultSeedUsecase(),
      ),
    );
  });

  tearDown(() async {
    await repository.close();
    await database.close();
  });

  test('publishes local commits but not recovered inventory', () async {
    var changes = 0;
    final subscription = facade.watchCommittedChanges().listen(
      (_) => changes++,
    );
    addTearDown(subscription.cancel);

    expect(
      await facade.recordReservedDerivation(
        reservationId: 'btcpay_wallet_seed',
        parentFingerprint: manifestFingerprint,
        derivationPath: "39'/0'/12'/100'",
        wallets: [_wallet('btcpay')],
      ),
      isA<Ok<bool, KeychainManifestFailure>>(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(changes, 1);

    expect(
      await facade.recordRecoveredDerivation(
        reservationId: 'lightning_address_wallet_seed',
        parentFingerprint: manifestFingerprint,
        derivationPath: "39'/0'/12'/101'",
        wallets: [_wallet('lightning')],
      ),
      isA<Ok<bool, KeychainManifestFailure>>(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(changes, 1, reason: 'recovery must not immediately republish');
  });

  test('publishes writes made by same-feature use cases', () async {
    var changes = 0;
    final subscription = facade.watchCommittedChanges().listen(
      (_) => changes++,
    );
    addTearDown(subscription.cancel);
    final record = RecordKeychainManifestNostrKeyUsecase(repository);
    expect(
      await record.execute(
        reservationId: 'nostr_user_key',
        parentFingerprint: manifestFingerprint,
        derivationPath: "128002'/1'/1'",
        publicKeyHex: '1' * 64,
        keyKind: KeychainManifestNostrKeyKind.userGenerated,
        purpose: 'Personal',
        now: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      ),
      isA<Ok<bool, KeychainManifestFailure>>(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(changes, 1);

    final entry =
        ((await repository.fetch(manifestFingerprint))
                as Ok<List<KeychainManifestEntry>, KeychainManifestFailure>)
            .value
            .single;
    expect(
      await UpdateKeychainManifestNostrKeyUsecase(repository).execute(
        entry: entry,
        purpose: 'Renamed',
        now: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
      ),
      isA<Ok<void, KeychainManifestFailure>>(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(changes, 2);
  });

  test('builds, parses, and canonicalizes through one codec', () async {
    await facade.recordReservedDerivation(
      reservationId: 'btcpay_wallet_seed',
      parentFingerprint: manifestFingerprint,
      derivationPath: "39'/0'/12'/100'",
      wallets: [_wallet('btcpay')],
    );
    final built = await facade.buildManifestFilePayload(manifestFingerprint);
    final payload = (built as Ok<String, KeychainManifestFailure>).value;
    expect(
      facade.canonicalizeManifestFilePayload(payload),
      isA<Ok<String, KeychainManifestFailure>>().having(
        (value) => value.value,
        'canonical payload',
        payload,
      ),
    );
    expect(
      facade.parseManifestFilePayload(
        payload,
        expectedParentFingerprint: manifestFingerprint,
      ),
      isA<Ok<KeychainManifestImportPlan, KeychainManifestFailure>>(),
    );
  });

  test('rejects an empty inventory unless explicitly allowed', () async {
    expect(
      await facade.buildManifestFilePayload(manifestFingerprint),
      isA<Err<String, KeychainManifestFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<KeychainManifestEmptyFailure>(),
      ),
    );
    expect(
      await facade.buildManifestFilePayload(
        manifestFingerprint,
        allowEmpty: true,
      ),
      isA<Ok<String, KeychainManifestFailure>>(),
    );
  });
}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

KeychainManifestWalletBinding _wallet(String id) =>
    KeychainManifestWalletBinding(
      walletId: id,
      childSeedFingerprint: Fingerprint('fedcba98'),
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
    );
