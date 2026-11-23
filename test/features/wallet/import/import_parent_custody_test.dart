import 'package:wallet_import/wallet_import.dart';
import 'package:all_seed_view/testing.dart';

import '../../../support/inventory_fixture.dart';
import '../../../support/wallet_registrations.dart';

import 'dart:async';
import 'dart:io';

import 'package:preferences/preferences.dart' hide Language;
import 'package:swaps/swaps.dart' show SwapStore;
import 'package:wallet_import/testing.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:secrets/custody.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_with_seed_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart'
    show Balances, SyncReason, SyncFailure, WalletKey;

class _Settings extends Mock implements Preferences {}

class _Swaps extends Mock implements SwapStore {}

class _Native extends Fake implements WalletNativeLifecycle {
  Future<void> Function()? beforeCreate;
  int creates = 0;
  @override
  Future<Result<void, SyncFailure>> prepareCreate(WalletKey key) async =>
      const Ok(null);
  @override
  Future<Result<void, SyncFailure>> create(WalletKey key) async {
    creates++;
    await beforeCreate?.call();
    return const Ok(null);
  }

  @override
  Future<Result<void, SyncFailure>> delete(WalletKey key) async =>
      const Ok(null);
  @override
  Future<Result<void, SyncFailure>> catalogDeleted(WalletKey key) async =>
      const Ok(null);
}

class _Values extends Fake implements SyncWalletValuesDatasource {
  Future<void> Function()? beforeRead;
  @override
  Future<Balances> getBalance({required WalletKey key}) async {
    await beforeRead?.call();
    return Balances(
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
  late WalletRegistrations metadata;
  late InventoryFixture fixture;
  late SqliteParentCustodyAdmission admission;
  late Secrets secrets;
  late WalletRepository repository;
  late ImportWalletUsecase importer;
  late DeleteWalletUsecase delete;
  late _Native native;
  late _Values values;
  late _Settings settings;
  late SeedReferences references;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('import-custody-');
    log = Logger.replace(directory: directory);
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => directory.path);
    metadata = MemoryWalletRegistrations();
    fixture = await InventoryFixture.open(directory);
    admission = SqliteParentCustodyAdmission(
      directory: () async => directory.path,
      mayCreate: true,
      waitLimit: const Duration(milliseconds: 100),
    );
    native = _Native();
    values = _Values();
    repository = WalletRepository(
      native: native,
      walletRegistrations: metadata,
      walletValuesDatasource: values,
      synchronize: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {},
      syncStarted: const Stream.empty(),
      syncFinished: const Stream.empty(),
    );
    settings = _Settings();
    when(settings.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    importer = ImportWalletUsecase(
      checkDuplicateMnemonicUsecase: CheckDuplicateMnemonicUsecase(
        secrets: secrets,
        inventory: fixture.inventory,
        settings: settings,
      ),
      secrets: secrets,
      settingsRepository: settings,
      provision: repository.importWallet,
      admission: admission,
    );
    references = SeedReferences(fixture.inventory, admission: admission);
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
    await fixture.close();
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
      expect(first, isA<Ok<void, ImportMnemonicFailure>>());
      expect(
        await delete.execute(walletId: (await metadata.fetchAll()).single.id),
        isA<Ok>(),
      );
      expect((await secrets.exists(parent) as Ok).value, isFalse);
      final second = await importer.execute(
        mnemonicWords: words,
        language: Language.english,
      );
      expect(second, isA<Ok<void, ImportMnemonicFailure>>());
      expect(
        await delete.execute(walletId: (await metadata.fetchAll()).single.id),
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
          inventory: fixture.inventory,
          settings: settings,
        ),
        secrets: secrets,
        settingsRepository: settings,
        provision: repository.importWallet,
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
    expect(result, isA<Ok<void, ImportMnemonicFailure>>());
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
      await delete.execute(walletId: (await metadata.fetchAll()).single.id),
      isA<Ok>(),
    );
    await fixture.close();
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
