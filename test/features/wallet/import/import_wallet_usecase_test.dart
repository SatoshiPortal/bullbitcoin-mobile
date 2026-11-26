import 'dart:io';

import 'package:primitives/primitives.dart'
    show BitcoinNetwork, BitcoinUnit, Err, Fingerprint, Ok, Result;
import 'package:provisioning/provisioning.dart';
import 'package:sync/sync.dart' show SyncFailure, SyncStorageFailure, WalletKey;
import 'package:sync/write.dart' show WalletNativeLifecycle;

import '../../../support/inventory_fixture.dart';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:preferences/preferences.dart';
import 'package:wallet_import/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';
import 'package:wallet_import/wallet_import.dart';

class _MockCheckDuplicateMnemonicUsecase extends Mock
    implements CheckDuplicateMnemonicUsecase {}

class _MockSettingsRepository extends Mock implements Preferences {}

final class _Native extends Fake implements WalletNativeLifecycle {
  Future<Result<void, SyncFailure>> Function()? beforeCreate;
  int creates = 0;

  @override
  Future<Result<void, SyncFailure>> prepareCreate(WalletKey key) async =>
      const Ok(null);

  @override
  Future<Result<void, SyncFailure>> create(WalletKey key) async {
    creates++;
    return beforeCreate?.call() ?? const Ok(null);
  }

  @override
  Future<Result<void, SyncFailure>> delete(WalletKey key) async =>
      const Ok(null);

  @override
  Future<Result<void, SyncFailure>> catalogDeleted(WalletKey key) async =>
      const Ok(null);

  @override
  Future<Result<int?, SyncFailure>> issuedReceiveIndex(WalletKey key) async =>
      const Ok(null);

  @override
  Future<Result<({String address, int index}), SyncFailure>> receive(
    WalletKey key, {
    bool advance = false,
  }) async => const Ok((address: 'unused', index: 0));
}

/// Admits every parent immediately; the admission lock itself is covered by
/// the custody tests.
final class _Admission implements ParentCustodyAdmissionPort {
  int runs = 0;

  @override
  Future<Result<T, ParentCustodyFailure>> runExclusive<T>(
    Fingerprint parent,
    Future<Result<T, ParentCustodyFailure>> Function(ParentCustodyLease) action,
  ) {
    runs++;
    return action(_Lease());
  }
}

final class _Lease implements ParentCustodyLease {
  @override
  Result<ParentCustodyState, ParentCustodyFailure> readState() =>
      const Ok(ParentCustodyState.ready);

  @override
  Result<void, ParentCustodyFailure> markDeleting() => const Ok(null);

  @override
  Result<void, ParentCustodyFailure> markDeleted() => const Ok(null);

  @override
  Result<void, ParentCustodyFailure> reconcilePresent() => const Ok(null);
}

void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];
  final settings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
  );

  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _MockCheckDuplicateMnemonicUsecase checkDuplicate;
  late _MockSettingsRepository settingsRepository;
  late _Native native;
  late InventoryFixture fixture;
  late WalletProvisioning accounts;
  late ImportWalletUsecase usecase;

  setUpAll(() {
    // mocktail requires a fallback for every non-nullable value a stub matches
    // with `any()`: the duplicate preflight is queried by parent and network.
    registerFallbackValue(Fingerprint('73c5da0a'));
    registerFallbackValue(BitcoinNetwork.mainnet);
  });

  ImportWalletUsecase usecaseWith(CheckDuplicateMnemonicUsecase duplicate) =>
      ImportWalletUsecase(
        checkDuplicateMnemonicUsecase: duplicate,
        secrets: secrets,
        settingsRepository: settingsRepository,
        provision: accounts.importMnemonic,
        admission: _Admission(),
      );

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    final directory = await Directory.systemTemp.createTemp('import-wallet-');
    addTearDown(() => directory.delete(recursive: true));
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    fixture = await InventoryFixture.open(directory);
    addTearDown(fixture.close);
    native = _Native();
    accounts = WalletProvisioning.open(
      inventory: fixture.inventory,
      native: native,
      resume: () async => const Ok(null),
      properties: const [],
    );
    checkDuplicate = _MockCheckDuplicateMnemonicUsecase();
    settingsRepository = _MockSettingsRepository();
    usecase = usecaseWith(checkDuplicate);
    when(
      () => checkDuplicate.execute(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
        language: bip39.Language.english,
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(() => checkDuplicate.isReferenced(any(), any()))
        .thenAnswer((_) async => const Ok(false));
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => Ok(settings));
  });

  for (final language in bip39.Language.values) {
    test(
      'imports ${language.name} only as a non-default Bitcoin wallet',
      () async {
        final duplicate = CheckDuplicateMnemonicUsecase(
          inventory: fixture.inventory,
          settings: settingsRepository,
          secrets: secrets,
        );
        final usecase = usecaseWith(duplicate);
        final words = bip39.Mnemonic(List.filled(16, 0), language).words;
        final result = await usecase.execute(
          mnemonicWords: words,
          language: language,
          label: 'Vector',
        );
        expect(result, isA<Ok<void, ImportMnemonicFailure>>());

        final entries =
            (await secrets.list() as Ok<List<SecretEntry>, SecretFailure>)
                .value;
        final secret = entries.single as Secret;
        expect(secret.info.language, language);
        final wallets =
            (await fixture.inventory.listWallets()
                    as Ok<List<RegisteredWallet>, SecretFailure>)
                .value;
        final wallet = wallets.single;
        expect(wallet.network, 'bitcoinMainnet');
        expect(wallet.label, 'Vector');
        expect(wallet.isDefault, isFalse);
        expect(wallet.secretFingerprint, secret.id.hex);
        expect(native.creates, 1);
        // The first successful provisioning now references this secret on mainnet.
        final retried = await usecase.execute(
          mnemonicWords: words,
          language: language,
        );
        expect((retried as Err).failure, isA<ImportMnemonicDuplicateFailure>());
        expect(
          (await secrets.exists(secret.id) as Ok<bool, SecretFailure>).value,
          isTrue,
        );
      },
    );
  }

  group('ImportWalletUsecase', () {
    test('returns success and stores the secret', () async {
      final result = await usecase.execute(
        mnemonicWords: words,
        label: 'My Wallet',
        language: bip39.Language.english,
      );

      expect(result, isA<Ok<void, ImportMnemonicFailure>>());
      expect(
        storage.entries.keys.where((k) => k.startsWith('seed_')),
        hasLength(1),
      );
      final wallets =
          (await fixture.inventory.listWallets()
                  as Ok<List<RegisteredWallet>, SecretFailure>)
              .value;
      expect(wallets.single.label, 'My Wallet');
      expect(wallets.single.isDefault, isFalse);
    });

    test('#2634 retries an orphan secret without replacing custody', () async {
      var attempts = 0;
      native.beforeCreate = () async =>
          ++attempts == 1 ? const Err(SyncStorageFailure()) : const Ok(null);
      expect(
        await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        ),
        isA<Err>(),
      );
      final keys = storage.entries.keys
          .where((k) => k.startsWith('seed_'))
          .toList();
      expect(keys, hasLength(1));
      expect(
        (await fixture.inventory.listWallets()
                as Ok<List<RegisteredWallet>, SecretFailure>)
            .value,
        isEmpty,
        reason: 'the failed native create compensates its catalog row',
      );
      expect(
        await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        ),
        isA<Ok<void, ImportMnemonicFailure>>(),
      );
      expect(storage.entries.keys.where((k) => k.startsWith('seed_')), keys);
      expect(native.creates, 2);
    });

    test('a duplicate stops before anything else is touched', () async {
      final before = Map<String, String>.of(storage.entries);
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
          language: bip39.Language.english,
        ),
      ).thenAnswer((_) async => const Err(ImportMnemonicDuplicateFailure()));

      final result = await usecase.execute(
        mnemonicWords: words,
        language: bip39.Language.english,
      );

      expect((result as Err).failure, isA<ImportMnemonicDuplicateFailure>());
      verifyNever(() => settingsRepository.fetch());
      expect(native.creates, 0);
      expect(
        storage.entries.length == before.length &&
            before.entries.every(
              (entry) => storage.entries[entry.key] == entry.value,
            ),
        isTrue,
        reason: 'duplicate detection must not change secure storage',
      );
    });

    test(
      'a failed wallet import preserves its secret for explicit recovery',
      () async {
        native.beforeCreate = () async => const Err(SyncStorageFailure());

        final result = await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        );

        expect((result as Err).failure, isA<ImportMnemonicUnexpectedFailure>());
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
          reason: 'orphan cleanup requires explicit user action',
        );
      },
    );

    test(
      'strict import rejects a referenced duplicate without cleanup',
      () async {
        when(() => checkDuplicate.isReferenced(any(), any()))
            .thenAnswer((_) async => const Ok(true));
        // The mocked preflight says the words are new, as it can after a stale
        // read or a concurrent storage operation. Import still rejects them.
        expect(
          await secrets.import(words: words, language: bip39.Language.english),
          isA<Ok<Secret, SecretFailure>>(),
        );

        final result = await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        );

        expect((result as Err).failure, isA<ImportMnemonicDuplicateFailure>());
        expect(
          (await fixture.inventory.listWallets()
                  as Ok<List<RegisteredWallet>, SecretFailure>)
              .value,
          isEmpty,
        );
        expect(native.creates, 0);
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
        );
      },
    );

    test('an unavailable inventory stops orphan retry', () async {
      const failure = ImportMnemonicUnexpectedFailure('Inventory unavailable');
      when(() => checkDuplicate.isReferenced(any(), any()))
          .thenAnswer((_) async => const Err(failure));
      expect(
        await secrets.import(words: words, language: bip39.Language.english),
        isA<Ok<Secret, SecretFailure>>(),
      );

      final result = await usecase.execute(
        mnemonicWords: words,
        language: bip39.Language.english,
      );

      expect((result as Err).failure, same(failure));
      expect(native.creates, 0);
      expect(
        (await fixture.inventory.listWallets()
                as Ok<List<RegisteredWallet>, SecretFailure>)
            .value,
        isEmpty,
      );
    });

    test(
      'concurrent imports create one wallet and preserve its secret',
      () async {
        final usecase = usecaseWith(
          CheckDuplicateMnemonicUsecase(
            inventory: fixture.inventory,
            settings: settingsRepository,
            secrets: secrets,
          ),
        );

        final results = await Future.wait([
          usecase.execute(
            mnemonicWords: words,
            language: bip39.Language.english,
          ),
          usecase.execute(
            mnemonicWords: words,
            language: bip39.Language.english,
          ),
        ]);

        expect(
          (results.last as Err).failure,
          isA<ImportMnemonicDuplicateFailure>(),
        );
        expect(native.creates, 1);
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
        );
      },
    );

    test(
      'an import refused after publication keeps the referenced secret',
      () async {
        expect(
          await usecase.execute(
            mnemonicWords: words,
            language: bip39.Language.english,
          ),
          isA<Ok<void, ImportMnemonicFailure>>(),
        );
        when(() => checkDuplicate.isReferenced(any(), any()))
            .thenThrow(Exception('inventory lookup failed after publication'));

        final result = await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        );

        expect((result as Err).failure, isA<ImportMnemonicUnexpectedFailure>());
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
        );
        expect(
          (await fixture.inventory.listWallets()
                  as Ok<List<RegisteredWallet>, SecretFailure>)
              .value,
          hasLength(1),
        );
        expect(native.creates, 1);
      },
    );

    test(
      'cleanup retains the new secret when wallet references cannot be read',
      () async {
        when(() => checkDuplicate.isReferenced(any(), any()))
            .thenThrow(Exception('wallet lookup failed'));
        expect(
          await secrets.import(words: words, language: bip39.Language.english),
          isA<Ok<Secret, SecretFailure>>(),
        );

        final result = await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        );

        expect((result as Err).failure, isA<ImportMnemonicUnexpectedFailure>());
        expect(
          storage.entries.keys.where((k) => k.startsWith('seed_')),
          hasLength(1),
        );
      },
    );
  });
}
