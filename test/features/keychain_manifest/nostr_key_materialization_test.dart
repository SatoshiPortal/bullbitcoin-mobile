import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' as wallet;
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/revealed_nostr_secret.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/create_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/reveal_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_keychain_manifest_nostr_key_usecase.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockSettings extends Mock implements GetSettingsUsecase {}

class _MockDefaultSeed extends Mock implements GetDefaultSeedUsecase {}

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main() {
  late Seed seed;
  late _MockSettings settings;
  late _MockDefaultSeed defaultSeed;
  late KeychainManifestNostrKeyDeriver deriver;

  setUpAll(() {
    final bytes = Uint8List.fromList(
      bip39.Mnemonic.fromSentence(_mnemonic, bip39.Language.english).seed,
    );
    seed = Seed.bytes(
      bytes: bytes,
      masterFingerprint: hex.encode(
        bip32.Bip32Keys.fromSeed(bytes).fingerprint,
      ),
    );
  });

  setUp(() {
    settings = _MockSettings();
    defaultSeed = _MockDefaultSeed();
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
    deriver = KeychainManifestNostrKeyDeriver(settings, defaultSeed);
  });

  test('keeps the first user identity derivation byte-stable', () {
    final publicKey = deriver.derivePublicKey(seed, "128002'/1'/1'");
    final secret = deriver.revealSecret(seed, "128002'/1'/1'");
    // These values are permanent user identity material; any change requires
    // an explicit wire/identity migration decision.
    expect(
      publicKey,
      'c071c9b02afd19a9d9b240ea9eed3f8ba80f89474953b752471f3d006b63a332',
    );
    expect(
      secret.nsec,
      'nsec17s2p4ad3hpd3xs70ssq2xydj076uz6kw25m7umlf25hzmktlxydsw2t3sg',
    );
  });

  test('uses the active environment and maps expected seed failures', () async {
    when(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).thenAnswer(
      (_) async => const Err<Seed, SeedFailure>(DefaultSeedNotFoundFailure()),
    );
    expect(
      await deriver.source(),
      isA<Err<KeychainManifestSeedSource, KeychainManifestFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<KeychainManifestSeedFailure>(),
      ),
    );
    verify(
      () => defaultSeed.execute(environment: Environment.mainnet),
    ).called(1);
  });

  test(
    'allocates after the durable high-water mark and skips app ids',
    () async {
      final repository = _MemoryRepository([
        _userEntry(seed, identity: 99, deriver: deriver),
      ]);
      final create = CreateKeychainManifestNostrKeyUsecase(
        deriver,
        repository,
        RecordKeychainManifestNostrKeyUsecase(repository),
      );
      final result = await create.execute(
        purpose: ' personal identity ',
        description: ' notes ',
        now: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
      );
      final entry =
          (result as Ok<KeychainManifestEntry, KeychainManifestFailure>).value;
      final key = entry.materializations.single as KeychainManifestNostrKey;
      expect(entry.bip85DerivationPath, "128002'/200'/1'");
      expect((key.purpose, entry.description), ('personal identity', 'notes'));
    },
  );

  test(
    'ignores non-BIP85 manifest entries when allocating an identity',
    () async {
      final parent = Fingerprint(seed.masterFingerprint);
      final child = Fingerprint('12345678');
      const path = "m/84'/0'/0'";
      final repository = _MemoryRepository([
        KeychainManifestEntry(
          parentFingerprint: parent,
          derivationKind: KeychainManifestDerivationKind.bip32,
          derivationPath: path,
          createdAt: 1,
          updatedAt: 1,
          materializations: [
            KeychainManifestWallet(
              walletId: 'imported-wallet',
              entryId: KeychainManifestEntry.entryIdFor(
                parentFingerprint: parent,
                derivationKind: KeychainManifestDerivationKind.bip32,
                derivationPath: path,
                seedFingerprint: child,
              ),
              childSeedFingerprint: child,
              network: wallet.Network.bitcoinMainnet,
              scriptType: wallet.ScriptType.bip84,
              provenance: WalletProvenance.importedMnemonic,
              seedPassphraseUsed: false,
              createdAt: 1,
              updatedAt: 1,
            ),
          ],
        ),
      ]);
      final create = CreateKeychainManifestNostrKeyUsecase(
        deriver,
        repository,
        RecordKeychainManifestNostrKeyUsecase(repository),
      );

      final result = await create.execute(purpose: 'Personal identity');

      expect(result, isA<Ok<KeychainManifestEntry, KeychainManifestFailure>>());
    },
  );

  test('reveals only a verified manifest key and redacts toString', () async {
    final entry = _userEntry(seed, identity: 1, deriver: deriver);
    final result = await RevealKeychainManifestNostrKeyUsecase(
      deriver,
    ).execute(entry);
    final secret =
        (result as Ok<RevealedNostrSecret, KeychainManifestFailure>).value;
    expect(secret.nsec, startsWith('nsec1'));
    expect(secret.toString(), isNot(contains(secret.nsec)));

    final reserved = _reservedEntry(seed, deriver);
    expect(
      await RevealKeychainManifestNostrKeyUsecase(deriver).execute(reserved),
      isA<Ok<RevealedNostrSecret, KeychainManifestFailure>>(),
    );
  });

  test('restores only a key derived from the active seed', () async {
    final repository = _MemoryRepository();
    final path = "128002'/1'/1'";
    final parentFingerprint = Fingerprint(seed.masterFingerprint);
    final restore = RestoreKeychainManifestNostrKeyUsecase(
      deriver,
      RecordKeychainManifestNostrKeyUsecase(repository),
    );

    expect(
      await restore.execute(
        reservationId: 'nostr_user_key',
        parentFingerprint: parentFingerprint,
        derivationPath: path,
        publicKeyHex: deriver.derivePublicKey(seed, path),
        keyKind: KeychainManifestNostrKeyKind.userGenerated,
        purpose: 'Personal identity',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      ),
      isA<Ok<bool, KeychainManifestFailure>>(),
    );
    expect(repository.entries, hasLength(1));

    expect(
      await restore.execute(
        reservationId: 'nostr_user_key',
        parentFingerprint: Fingerprint('00000000'),
        derivationPath: path,
        publicKeyHex: deriver.derivePublicKey(seed, path),
        keyKind: KeychainManifestNostrKeyKind.userGenerated,
        purpose: 'Personal identity',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      ),
      isA<Err<bool, KeychainManifestFailure>>(),
    );
  });
}

KeychainManifestEntry _userEntry(
  Seed seed, {
  required int identity,
  required KeychainManifestNostrKeyDeriver deriver,
}) {
  final path = "128002'/$identity'/1'";
  final parent = Fingerprint(seed.masterFingerprint);
  final entryId = '${parent.hex}:$path';
  final publicKey = deriver.derivePublicKey(seed, path);
  return KeychainManifestEntry(
    parentFingerprint: parent,
    derivationPath: path,
    description: 'key $identity',
    createdAt: 1,
    updatedAt: 1,
    materializations: [
      KeychainManifestNostrKey(
        entryId: entryId,
        publicKeyHex: publicKey,
        keyKind: KeychainManifestNostrKeyKind.userGenerated,
        purpose: 'key $identity',
        createdAt: 1,
        updatedAt: 1,
      ),
    ],
  );
}

KeychainManifestEntry _reservedEntry(
  Seed seed,
  KeychainManifestNostrKeyDeriver deriver,
) {
  const path = "128002'/100'/1'";
  final parent = Fingerprint(seed.masterFingerprint);
  final entryId = '${parent.hex}:$path';
  final publicKey = deriver.derivePublicKey(seed, path);
  return KeychainManifestEntry(
    parentFingerprint: parent,
    derivationPath: path,
    createdAt: 1,
    updatedAt: 1,
    materializations: [
      KeychainManifestNostrKey(
        entryId: entryId,
        publicKeyHex: publicKey,
        keyKind: KeychainManifestNostrKeyKind.reserved,
        purpose: 'Wallet backup',
        createdAt: 1,
        updatedAt: 1,
      ),
    ],
  );
}

final class _MemoryRepository implements KeychainManifestRepository {
  final List<KeychainManifestEntry> entries;

  _MemoryRepository([List<KeychainManifestEntry>? entries])
    : entries = [...?entries];

  @override
  Stream<void> watchLocalChanges() => const Stream.empty();

  @override
  Future<Result<List<KeychainManifestEntry>, KeychainManifestFailure>> fetch(
    Fingerprint parentFingerprint,
  ) async => Ok([
    for (final entry in entries)
      if (entry.parentFingerprint == parentFingerprint) entry,
  ]);

  @override
  Future<Result<void, KeychainManifestFailure>> insertNostrKey(
    KeychainManifestEntry record, {
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  }) async {
    if (entries.any((entry) => entry.entryId == record.entryId)) {
      return const Err(KeychainManifestConflictFailure());
    }
    entries.add(record);
    return const Ok(null);
  }

  @override
  Future<Result<void, KeychainManifestFailure>> replaceSeedWalletInventory(
    Fingerprint parentFingerprint,
    List<KeychainManifestEntry> replacements,
  ) async {
    entries.removeWhere(
      (entry) =>
          entry.parentFingerprint == parentFingerprint &&
          entry.derivationKind == KeychainManifestDerivationKind.bip32,
    );
    entries.addAll(replacements);
    return const Ok(null);
  }

  @override
  Future<Result<void, KeychainManifestFailure>> upsertPassphraseWallet(
    KeychainManifestEntry record,
  ) async => const Err(KeychainManifestConflictFailure());

  @override
  Future<Result<KeychainManifestRestoreReport, KeychainManifestFailure>>
  restoreSnapshot(
    KeychainManifest manifest, {
    KeychainManifestRestorePolicy policy =
        KeychainManifestRestorePolicy.keepNewest,
  }) async => const Err(KeychainManifestConflictFailure());

  @override
  Future<Result<void, KeychainManifestFailure>> updatePassphraseLabelHint({
    required Fingerprint parentFingerprint,
    required String walletId,
    KeychainManifestEdit<String?>? label,
    KeychainManifestEdit<String?>? hint,
    required int updatedAt,
  }) async => const Err(KeychainManifestConflictFailure());

  @override
  Future<Result<void, KeychainManifestFailure>> removePassphraseWallet({
    required Fingerprint parentFingerprint,
    required String walletId,
  }) async => const Err(KeychainManifestConflictFailure());

  @override
  Future<Result<void, KeychainManifestFailure>> updateNostrMetadata({
    required Fingerprint parentFingerprint,
    required String entryId,
    required String purpose,
    String? description,
    required int updatedAt,
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  }) async => const Err(KeychainManifestConflictFailure());

  @override
  Future<void> close() async {}
}
