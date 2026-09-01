import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
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
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/watch_keychain_manifest_changes_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/update_passphrase_label_hint_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;

import 'support/manifest_fixtures.dart';

class _MockSettings extends Mock implements GetSettingsUsecase {}

class _MockDefaultSeed extends Mock implements GetDefaultSeedUsecase {}

void main() {
  late SqliteDatabase database;
  late KeychainManifestRepositoryImpl repository;
  late KeychainManifestFacade facade;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    repository = KeychainManifestRepositoryImpl(database);
    const codec = KeychainManifestFileCodec();
    final parse = ParseKeychainManifestFileUsecase(codec.decode);
    facade = KeychainManifestFacade(
      WatchKeychainManifestChangesUsecase(repository),
      codec.encode,
      BuildKeychainManifestFileUsecase(repository),
      parse,
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
      await facade.replaceSeedWalletInventory(
        parentFingerprint: manifestFingerprint,
        wallets: [_inventory('default-bitcoin')],
      ),
      isA<Ok<bool, KeychainManifestFailure>>(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(changes, 1);
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
  });

  test('builds and parses through one codec', () async {
    expect(
      await facade.replaceSeedWalletInventory(
        parentFingerprint: manifestFingerprint,
        wallets: [_inventory('default-bitcoin')],
      ),
      isA<Ok<bool, KeychainManifestFailure>>(),
    );
    final built = await _buildPayload(facade, manifestFingerprint);
    final payload = (built as Ok<String, KeychainManifestFailure>).value;
    expect(
      facade.parseManifestFilePayload(
        payload,
        expectedParentFingerprint: manifestFingerprint,
      ),
      isA<Ok<KeychainManifest, KeychainManifestFailure>>(),
    );
  });

  test('records seed-derived wallet facts without descriptors', () async {
    expect(
      await facade.replaceSeedWalletInventory(
        parentFingerprint: manifestFingerprint,
        wallets: [
          KeychainManifestWalletInventoryBinding(
            walletId: 'default-bitcoin',
            seedFingerprint: manifestFingerprint,
            network: Network.bitcoinMainnet,
            scriptType: ScriptType.bip84,
            provenance: WalletProvenance.defaultSeed,
            derivationPath: 'm/84h/0h/0h',
            seedPassphraseUsed: false,
          ),
          KeychainManifestWalletInventoryBinding(
            walletId: 'imported-bitcoin',
            seedFingerprint: Fingerprint('fedcba98'),
            network: Network.bitcoinMainnet,
            scriptType: ScriptType.bip84,
            provenance: WalletProvenance.importedMnemonic,
            derivationPath: "m/84'/0'/0'",
            seedPassphraseUsed: true,
          ),
        ],
      ),
      isA<Ok<bool, KeychainManifestFailure>>(),
    );

    final payload =
        ((await _buildPayload(facade, manifestFingerprint))
                as Ok<String, KeychainManifestFailure>)
            .value;
    expect(payload, contains('"derivationKind":"bip32"'));
    expect(payload, contains('"derivationPath":"m/84\'/0\'/0\'"'));
    expect(payload, contains('"provenance":"defaultSeed"'));
    expect(payload, contains('"provenance":"importedMnemonic"'));
    expect(payload, isNot(contains('descriptor')));

    final parsed =
        (facade.parseManifestFilePayload(
                  payload,
                  expectedParentFingerprint: manifestFingerprint,
                )
                as Ok<KeychainManifest, KeychainManifestFailure>)
            .value;
    expect(parsed.wallets.length, 2);
    expect(
      parsed.entries.map((entry) => entry.entryId).toSet().length,
      2,
      reason: 'different seed roots may use the same BIP32 account path',
    );
    expect(
      parsed.wallets
          .singleWhere((wallet) => wallet.walletId == 'imported-bitcoin')
          .seedPassphraseUsed,
      isTrue,
    );
  });

  test(
    'refreshes current wallets while retaining recovered mnemonic facts',
    () async {
      final defaultWallet = KeychainManifestWalletInventoryBinding(
        walletId: 'default-bitcoin',
        seedFingerprint: manifestFingerprint,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        provenance: WalletProvenance.defaultSeed,
        derivationPath: "m/84'/0'/0'",
        seedPassphraseUsed: false,
      );
      final importedWallet = KeychainManifestWalletInventoryBinding(
        walletId: 'imported-bitcoin',
        seedFingerprint: Fingerprint('fedcba98'),
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        provenance: WalletProvenance.importedMnemonic,
        derivationPath: "m/84'/0'/0'",
        seedPassphraseUsed: true,
      );
      expect(
        await facade.replaceSeedWalletInventory(
          parentFingerprint: manifestFingerprint,
          wallets: [defaultWallet, importedWallet],
        ),
        isA<Ok>(),
      );

      expect(
        await facade.replaceSeedWalletInventory(
          parentFingerprint: manifestFingerprint,
          wallets: const [],
        ),
        isA<Ok>(),
      );

      final manifest =
          ((await facade.readManifest(manifestFingerprint))
                  as Ok<KeychainManifest, KeychainManifestFailure>)
              .value;
      final wallets = manifest.entries
          .expand((entry) => entry.materializations)
          .whereType<KeychainManifestWallet>()
          .toList(growable: false);
      expect(wallets, hasLength(1));
      expect(wallets.single.walletId, 'imported-bitcoin');
      expect(wallets.single.provenance, WalletProvenance.importedMnemonic);
    },
  );

  test('preserves, updates, and forgets passphrase wallet records', () async {
    const walletId = 'passphrase-bitcoin';
    const descriptor = 'wpkh(public-descriptor/<0;1>/*)';
    final passphraseWallet = KeychainManifestWalletInventoryBinding(
      walletId: walletId,
      seedFingerprint: Fingerprint('01234567'),
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      provenance: WalletProvenance.defaultSeedPassphrase,
      derivationPath: "m/84'/0'/0'",
      seedPassphraseUsed: true,
      descriptor: descriptor,
      label: 'Vault',
      description: 'Original hint',
    );

    expect(
      await facade.replaceSeedWalletInventory(
        parentFingerprint: manifestFingerprint,
        wallets: [passphraseWallet],
      ),
      isA<Ok>(),
    );
    expect(
      await facade.replaceSeedWalletInventory(
        parentFingerprint: manifestFingerprint,
        wallets: const [],
      ),
      isA<Ok>(),
    );

    var manifest =
        ((await facade.readManifest(manifestFingerprint))
                as Ok<KeychainManifest, KeychainManifestFailure>)
            .value;
    expect(manifest.wallets.single.descriptor, descriptor);
    expect(manifest.wallets.single.label, 'Vault');
    expect(manifest.entries.single.description, 'Original hint');

    expect(
      await facade.updatePassphraseLabelHint(
        parentFingerprint: manifestFingerprint,
        walletId: walletId,
        hint: const KeychainManifestEdit('Updated hint'),
      ),
      isA<Ok>(),
    );
    manifest =
        ((await facade.readManifest(manifestFingerprint))
                as Ok<KeychainManifest, KeychainManifestFailure>)
            .value;
    expect(manifest.entries.single.description, 'Updated hint');

    expect(
      await facade.deleteWallet(
        parentFingerprint: manifestFingerprint,
        walletId: walletId,
      ),
      isA<Ok>(),
    );
    manifest =
        ((await facade.readManifest(manifestFingerprint))
                as Ok<KeychainManifest, KeychainManifestFailure>)
            .value;
    expect(manifest.entries, isEmpty);
  });

  test('rejects unsupported inventory provenance', () async {
    expect(
      await facade.replaceSeedWalletInventory(
        parentFingerprint: manifestFingerprint,
        wallets: [
          KeychainManifestWalletInventoryBinding(
            walletId: 'watch-only',
            seedFingerprint: Fingerprint('fedcba98'),
            network: Network.bitcoinMainnet,
            scriptType: ScriptType.bip84,
            provenance: WalletProvenance.watchOnly,
            derivationPath: "m/84'/0'/0'",
            seedPassphraseUsed: null,
          ),
        ],
      ),
      isA<Err<bool, KeychainManifestFailure>>(),
    );
  });

  test('rejects an empty inventory unless explicitly allowed', () async {
    expect(
      await _buildPayload(facade, manifestFingerprint),
      isA<Err<String, KeychainManifestFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<KeychainManifestEmptyFailure>(),
      ),
    );
    expect(
      await _buildPayload(facade, manifestFingerprint, allowEmpty: true),
      isA<Ok<String, KeychainManifestFailure>>(),
    );
  });
}

KeychainManifestWalletInventoryBinding _inventory(String id) =>
    KeychainManifestWalletInventoryBinding(
      walletId: id,
      seedFingerprint: manifestFingerprint,
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      provenance: WalletProvenance.defaultSeed,
      derivationPath: "m/84'/0'/0'",
      seedPassphraseUsed: false,
    );

Future<Result<String, KeychainManifestFailure>> _buildPayload(
  KeychainManifestFacade facade,
  Fingerprint parentFingerprint, {
  bool allowEmpty = false,
}) async => (await facade.buildManifest(
  parentFingerprint,
  allowEmpty: allowEmpty,
)).map(facade.encodeManifestFilePayload);
