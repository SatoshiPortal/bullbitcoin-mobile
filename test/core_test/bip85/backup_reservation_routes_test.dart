import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:io';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import '../../features/nostr_identity/fixtures/backup_secret_fixture.dart';

class _Wallets extends Mock implements WalletRepository {}

class _Wallet extends Mock implements Wallet {}

class _Settings extends Mock implements SettingsRepository {}

void main() {
  late SqliteDatabase database;
  late Bip85Datasource datasource;
  late Bip85Repository repository;
  TestWidgetsFlutterBinding.ensureInitialized();
  late Secret seed;
  late String fingerprint;

  Future<void> store(
    String path, {
    Bip85ApplicationColumn application = Bip85ApplicationColumn.bip39,
    String? owner,
  }) => database
      .into(database.bip85Derivations)
      .insert(
        Bip85DerivationsCompanion.insert(
          path: path,
          xprvFingerprint: owner ?? fingerprint,
          application: application,
          status: Bip85StatusColumn.active,
          alias: const Value('Kept alias'),
        ),
      )
      .then((_) {});

  setUp(() async {
    seed = await backupSecretFixture();
    fingerprint = seed.id.hex;
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = Bip85Datasource(sqlite: database);
    repository = Bip85Repository(datasource: datasource);
  });
  tearDown(() => database.close());

  test(
    'allocation skips backup words without inserting a synthetic derivation',
    () async {
      await store("39'/0'/12'/99'");
      expect(
        (await repository.fetchNextIndexForApplication(Bip85Application.bip39)
                as Ok<int, Bip85Failure>)
            .value,
        101,
      );
      expect((await datasource.fetchAll()).map((row) => row.index), [99]);
    },
  );

  test(
    'explicit-index derivation rejects backup words before persistence',
    () async {
      await expectLater(
        datasource.recordMnemonic(
          xprvFingerprint: fingerprint,
          length: bip39.MnemonicLength.words12,
          index: 100,
        ),
        throwsFormatException,
      );
      expect(await datasource.fetchAll(), isEmpty);
      expect(
        await repository.recordMnemonic(
          xprvFingerprint: fingerprint,
          length: bip39.MnemonicLength.words12,
          index: 100,
        ),
        isA<Err<dynamic, Bip85Failure>>(),
      );
    },
  );

  test(
    'allocation preserves the same index for non-12-word requests',
    () async {
      await store("39'/0'/12'/99'");
      for (final length in [
        bip39.MnemonicLength.words18,
        bip39.MnemonicLength.words24,
      ]) {
        final result = await repository.fetchNextIndexForApplication(
          Bip85Application.bip39,
          mnemonicLength: length,
        );
        expect((result as Ok<int, Bip85Failure>).value, 100);
      }
      await store("128169'/32'/99'", application: Bip85ApplicationColumn.hex);
      expect(
        (await repository.fetchNextIndexForApplication(Bip85Application.hex)
                as Ok<int, Bip85Failure>)
            .value,
        100,
      );
    },
  );

  test(
    'the same index stays available for other lengths and applications',
    () async {
      final longer = await datasource.recordMnemonic(
        xprvFingerprint: fingerprint,
        length: bip39.MnemonicLength.words24,
        index: 100,
        alias: 'Longer',
      );
      final hexadecimal = await datasource.recordHex(
        xprvFingerprint: fingerprint,
        length: 32,
        index: 100,
      );
      expect(longer, "39'/0'/24'/100'");
      expect(hexadecimal, "128169'/32'/100'");
      expect((await datasource.fetch(longer))!.alias, 'Longer');
    },
  );

  test(
    'listing and export omit reserved and retired keys and preserve the root check',
    () async {
      for (final path in [
        "39'/0'/12'/100'",
        "m/83696968h/39h/0h/12h/100h",
        "128002'/100'/1'",
        "1642'/0'/1'",
        "1608'/0'/0'",
      ]) {
        await store(path);
      }
      await store("39'/0'/12'/99'");
      await store("39'/0'/24'/100'");
      await store("39'/0'/12'/101'", owner: 'another-root');
      final listing =
          (await repository.fetchAll()
                  as Ok<List<Bip85DerivationEntity>, Bip85Failure>)
              .value;
      expect(
        listing.map((row) => row.path),
        unorderedEquals([
          "39'/0'/12'/99'",
          "39'/0'/24'/100'",
          "39'/0'/12'/101'",
        ]),
      );
      final wallets = _Wallets();
      final wallet = _Wallet();
      final settings = _Settings();
      when(() => wallet.masterFingerprint).thenReturn(fingerprint);
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(
        () => wallets.getWallets(
          environment: Environment.mainnet,
          onlyDefaults: true,
          onlyBitcoin: true,
        ),
      ).thenAnswer((_) async => Ok([wallet]));
      final result = await FetchAllBip85DerivationsWithEntropyUsecase(
        bip85Repository: repository,
        walletRepository: wallets,
        settingsRepository: settings,
        secrets: Secrets(
          scratchDirectory: () async => Directory.systemTemp.path,
        ),
      ).execute();
      final exported =
          (result
                  as Ok<
                    List<({Bip85DerivationEntity derivation, String entropy})>,
                    Bip85Failure
                  >)
              .value;
      expect(
        exported.map((row) => row.derivation.path),
        unorderedEquals(["39'/0'/12'/99'", "39'/0'/24'/100'"]),
      );
      expect(
        exported.every(
          (row) =>
              row.entropy.isNotEmpty && row.derivation.alias == 'Kept alias',
        ),
        isTrue,
      );
    },
  );

  test(
    'allocation reports exhaustion instead of returning a non-hardened index',
    () async {
      await store("39'/0'/12'/2147483647'");
      expect(
        await repository.fetchNextIndexForApplication(Bip85Application.bip39),
        isA<Err<int, Bip85Failure>>(),
      );
    },
  );
}
