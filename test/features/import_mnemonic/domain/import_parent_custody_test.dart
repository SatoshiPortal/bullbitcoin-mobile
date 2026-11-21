import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/features/all_seed_view/domain/usecases/delete_secret_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:preferences/preferences.dart' hide Language;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:swaps/swaps.dart' show SwapStore;
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/data/sqlite_parent_custody_admission.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/seed_reference_port.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_with_seed_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart' show SyncReason;

class _Settings extends Mock implements SettingsRepository {}

class _Swaps extends Mock implements SwapStore {}

class _Bdk extends Fake implements BdkWalletDatasource {}

class _Lwk extends Fake implements LwkWalletDatasource {}

class _Native extends Fake implements WalletNativeLifecycle {
  Future<void> Function()? beforeCreate;
  int creates = 0;
  @override
  Future<void> prepareCreate(WalletMetadataModel metadata) async {}
  @override
  Future<void> create(WalletMetadataModel metadata) async {
    creates++;
    await beforeCreate?.call();
  }

  @override
  Future<void> delete(WalletMetadataModel metadata) async {}
  @override
  Future<void> catalogDeleted(WalletMetadataModel metadata) async {}
}

class _Values extends Fake implements SyncWalletValuesDatasource {
  Future<void> Function()? beforeRead;
  @override
  Future<BalanceModel> getBalance({required WalletModel wallet}) async {
    await beforeRead?.call();
    return BalanceModel(
      confirmedSat: BigInt.zero,
      immatureSat: BigInt.zero,
      trustedPendingSat: BigInt.zero,
      untrustedPendingSat: BigInt.zero,
      spendableSat: BigInt.zero,
      totalSat: BigInt.zero,
    );
  }
}

final class _BeforeAdmission implements ParentCustodyAdmissionPort {
  final ParentCustodyAdmissionPort delegate;
  final Future<void> Function() before;
  _BeforeAdmission(this.delegate, this.before);
  @override
  Future<Result<T, ParentCustodyFailure>> runExclusive<T>(
    Fingerprint parent,
    Future<Result<T, ParentCustodyFailure>> Function(ParentCustodyLease) action,
  ) async {
    await before();
    return delegate.runExclusive(parent, action);
  }
}

final class _InventoryGate implements SeedReferencePort {
  final Completer<void> entered;
  final Completer<void> finish;
  _InventoryGate(this.entered, this.finish);
  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async {
    entered.complete();
    await finish.future;
    return Ok(<Fingerprint>{});
  }
}

void main() {
  // Public BIP39 test vector, never a funded wallet.
  final words = [...List.filled(11, 'abandon'), 'about'];
  final parent = Fingerprint('73c5da0a');
  late Directory directory;
  late SqliteDatabase database;
  late WalletMetadataDatasource metadata;
  late SqliteParentCustodyAdmission admission;
  late Secrets secrets;
  late WalletRepository repository;
  late ImportWalletUsecase importer;
  late DeleteWalletUsecase delete;
  late _Native native;
  late _Values values;
  late _Settings settings;
  late SeedReferences references;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('import-custody-');
    log = Logger.replace(directory: directory);
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => directory.path);
    database = SqliteDatabase(NativeDatabase.memory());
    metadata = WalletMetadataDatasource(sqlite: database);
    admission = SqliteParentCustodyAdmission(
      directory: () async => directory.path,
      mayCreate: true,
      waitLimit: const Duration(milliseconds: 100),
    );
    native = _Native();
    values = _Values();
    repository = WalletRepository(
      native: native,
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: _Bdk(),
      lwkWalletDatasource: _Lwk(),
      walletValuesDatasource: values,
      synchronize: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {},
      isSyncing: ({walletId}) => false,
      syncStarted: const Stream.empty(),
      syncFinished: const Stream.empty(),
      electrumSyncResultStream: const Stream.empty(),
    );
    settings = _Settings();
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    importer = ImportWalletUsecase(
      checkDuplicateMnemonicUsecase: CheckDuplicateMnemonicUsecase(
        secrets: secrets,
        metadata: metadata,
        settings: settings,
      ),
      secrets: secrets,
      settingsRepository: settings,
      walletRepository: repository,
      admission: admission,
    );
    references = SeedReferences(repository, admission: admission);
    final swaps = _Swaps();
    when(() => swaps.ongoing(walletId: any(named: 'walletId')))
        .thenAnswer((_) async => const Ok([]));
    delete = DeleteWalletUsecase(
      walletRepository: repository,
      swapStore: swaps,
      secrets: secrets,
      seedReferences: references,
    );
  });
  tearDown(() async {
    await database.close();
    await log.flush();
    directory.deleteSync(recursive: true);
  });

  test(
    'delete reimport delete removes the seed through production usecases',
    () async {
      final first = await importer.execute(
        mnemonicWords: words,
        language: Language.english,
      );
      expect(first, isA<Ok<Wallet, ImportMnemonicFailure>>());
      expect(await delete.execute(walletId: (first as Ok).value.id), isA<Ok>());
      expect((await secrets.exists(parent) as Ok).value, isFalse);
      final second = await importer.execute(
        mnemonicWords: words,
        language: Language.english,
      );
      expect(second, isA<Ok<Wallet, ImportMnemonicFailure>>());
      expect(
        await delete.execute(walletId: (second as Ok).value.id),
        isA<Ok>(),
      );
      expect(await metadata.fetchAll(), isEmpty);
      expect((await secrets.exists(parent) as Ok).value, isFalse);
    },
  );

  test(
    'explicit import reconciles a deleting tombstone after publication',
    () async {
      await admission.runExclusive<void>(
        parent,
        (lease) async => lease.markDeleting(),
      );
      expect(
        await importer.execute(
          mnemonicWords: words,
          language: Language.english,
        ),
        isA<Ok>(),
      );
      expect(await metadata.fetchAll(), hasLength(1));
      final result = await admission.runExclusive<ParentCustodyState>(
        parent,
        (lease) async => lease.readState(),
      );
      expect((result as Ok).value, ParentCustodyState.ready);
    },
  );

  ImportWalletUsecase importingWith(ParentCustodyAdmissionPort port) =>
      ImportWalletUsecase(
        checkDuplicateMnemonicUsecase: CheckDuplicateMnemonicUsecase(
          secrets: secrets,
          metadata: metadata,
          settings: settings,
        ),
        secrets: secrets,
        settingsRepository: settings,
        walletRepository: repository,
        admission: port,
      );

  test(
    'admitted import excludes deletion until publication and reconciliation',
    () async {
      final entered = Completer<void>();
      final finish = Completer<void>();
      native.beforeCreate = () async {
        entered.complete();
        await finish.future;
      };
      final importing = importer.execute(
        mnemonicWords: words,
        language: Language.english,
      );
      try {
        await entered.future;
        final deletion = await references.deleteUnreferenced(secrets, parent);
        expect((deletion as Err).failure, isA<ParentCustodyBusyFailure>());
        expect((await secrets.exists(parent) as Ok).value, isTrue);
      } finally {
        finish.complete();
      }
      expect(await importing, isA<Ok>());
      final state = await admission.runExclusive(
        parent,
        (lease) async => lease.readState(),
      );
      expect((state as Ok).value, ParentCustodyState.ready);
    },
  );

  test(
    'deletion blocked in inventory cannot race catalog publication',
    () async {
      expect(
        await secrets.import(words: words, language: Language.english),
        isA<Ok<Secret, SecretFailure>>(),
      );
      final entered = Completer<void>();
      final finish = Completer<void>();
      final attempted = Completer<void>();
      references.register(_InventoryGate(entered, finish));
      final deletion = references.deleteUnreferenced(secrets, parent);
      await entered.future;
      final importing = importingWith(
        _BeforeAdmission(admission, () async {
          attempted.complete();
        }),
      ).execute(mnemonicWords: words, language: Language.english);
      await attempted.future;
      expect(native.creates, 0);
      expect(await metadata.fetchAll(), isEmpty);
      finish.complete();
      expect(await deletion, isA<Ok>());
      expect(await importing, isA<Err>());
      expect(native.creates, 0);
      expect(await metadata.fetchAll(), isEmpty);
    },
  );

  test(
    'seed removed before admission fails fresh reread without catalog row',
    () async {
      final result = await importingWith(
        _BeforeAdmission(admission, () async {
          expect(await secrets.trash(parent), isA<Ok<void, SecretFailure>>());
        }),
      ).execute(mnemonicWords: words, language: Language.english);
      expect(result, isA<Err>());
      expect(native.creates, 0);
      expect(await metadata.fetchAll(), isEmpty);
      expect((await secrets.exists(parent) as Ok).value, isFalse);
    },
  );

  test(
    'balance observation runs after parent admission was released',
    () async {
      Result<ParentCustodyState, ParentCustodyFailure>? atBalance;
      values.beforeRead = () async {
        atBalance = await admission.runExclusive(
          parent,
          (lease) async => lease.readState(),
        );
      };
      expect(
        await importer.execute(
          mnemonicWords: words,
          language: Language.english,
        ),
        isA<Ok>(),
      );
      expect(atBalance, isA<Ok<ParentCustodyState, ParentCustodyFailure>>());
      expect((atBalance as Ok).value, ParentCustodyState.ready);
    },
  );

  test('real passphrase import cannot become a default wallet', () async {
    final result = await importer.execute(
      mnemonicWords: words,
      language: Language.english,
      passphrase: 'TREZOR',
    );
    expect(result, isA<Ok<Wallet, ImportMnemonicFailure>>());
    expect((result as Ok).value.isDefault, isFalse);
    expect((await metadata.fetchAll()).single.isDefault, isFalse);
  });

  for (final corrupt in [false, true]) {
    test(
      '${corrupt ? 'corrupt' : 'missing'} state refuses import and deletion explicitly',
      () async {
        await admission.runExclusive<void>(parent, (_) async => const Ok(null));
        final state = File(
          '${directory.path}/parent_custody/${parent.hex}.state.sqlite',
        );
        if (corrupt) {
          state.writeAsBytesSync([1, 2, 3]);
        } else {
          state.deleteSync();
        }
        final result = await importer.execute(
          mnemonicWords: words,
          language: Language.english,
        );
        expect(
          (result as Err).failure,
          isA<ImportMnemonicCustodyMetadataFailure>(),
        );
        final deleted = await DeleteSecretUsecase(
          secrets: secrets,
          seedReferences: references,
        ).execute(parent);
        expect(
          (deleted as Err).failure,
          isA<AllSeedViewCustodyMetadataFailure>(),
        );
        expect(await metadata.fetchAll(), isEmpty);
        expect((await secrets.exists(parent) as Ok).value, isTrue);
        expect(state.existsSync(), corrupt);
        if (corrupt) expect(state.readAsBytesSync(), [1, 2, 3]);
      },
    );
  }

  test('orphan cleanup reports a tombstone refusal distinctly', () async {
    final imported = await importer.execute(
      mnemonicWords: words,
      language: Language.english,
    );
    expect(imported, isA<Ok>());
    expect(
      await admission.runExclusive<void>(
        parent,
        (lease) async => lease.markDeleting(),
      ),
      isA<Ok>(),
    );
    expect(
      await delete.execute(walletId: (imported as Ok).value.id),
      isA<Ok>(),
    );
    await log.flush();
    final diagnostics = log.logsFile.readAsStringSync();
    expect(diagnostics, contains('Seed cleanup refused reason=custody_state'));
    expect(
      diagnostics,
      isNot(contains('Seed cleanup failed reason=references_unavailable')),
    );
    expect((await secrets.exists(parent) as Ok).value, isTrue);
  });
}
