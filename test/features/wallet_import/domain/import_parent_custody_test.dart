import 'dart:async';
import 'dart:io';

import 'package:all_seed_view/testing.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart' hide Language;
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/custody.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart' show SyncFailure, WalletKey;
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:wallet_import/testing.dart';
import 'package:wallet_import/wallet_import.dart';

import '../../../support/inventory_fixture.dart';

/// Answers the active environment with mainnet; the workspace is mainnet.
final class _Settings extends Fake implements Preferences {
  @override
  Future<Result<SettingsEntity, PreferencesFailure>> fetch() async => Ok(
    const SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
    ),
  );
}

final class _Native extends Fake implements WalletNativeLifecycle {
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
  late InventoryFixture fixture;
  late SqliteParentCustodyAdmission admission;
  late Secrets secrets;
  late WalletProvisioning accounts;
  late ImportWalletUsecase importer;
  late _Native native;
  late _Settings settings;
  late SeedReferences references;

  Future<List<RegisteredWallet>> rows() async =>
      switch (await fixture.inventory.listWallets()) {
        Ok(:final value) => value,
        Err(:final failure) => fail('listWallets: $failure'),
      };

  /// The custody stages of deleting one non-default wallet. The settings
  /// deletion usecase owns the user-facing checks and logging on top of them
  /// and is covered where it lives; this app test needs the real admission
  /// and the real seed-reference query, not those checks.
  Future<Result<void, Failure>> deleteWallet(String walletId) async {
    final registration = switch (await fixture.inventory.readWallet(walletId)) {
      Ok(:final value) => value,
      Err(:final failure) => fail('readWallet: $failure'),
    };
    expect(
      registration.isDefault,
      isFalse,
      reason: 'these cases delete a non-default wallet',
    );
    final key = WalletKey(id: registration.id, network: registration.network);
    expect(await native.delete(key), isA<Ok<void, SyncFailure>>());
    expect(
      await fixture.inventory.removeWallet(walletId),
      isA<Ok<void, SecretFailure>>(),
    );
    expect(await native.catalogDeleted(key), isA<Ok<void, SyncFailure>>());
    final fingerprint = registration.secretFingerprint;
    if (registration.signer != WalletSigner.local || fingerprint == null) {
      return const Ok(null);
    }
    return references.deleteUnreferenced(secrets, fingerprint);
  }

  ImportWalletUsecase importingWith(ParentCustodyAdmissionPort port) =>
      ImportWalletUsecase(
        checkDuplicateMnemonicUsecase: CheckDuplicateMnemonicUsecase(
          secrets: secrets,
          inventory: fixture.inventory,
          settings: settings,
        ),
        secrets: secrets,
        settingsRepository: settings,
        provision: accounts.importMnemonic,
        admission: port,
      );

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('import-custody-');
    log = Logger.replace(directory: directory);
    FakeSecureStoragePlatform().install();
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    fixture = await InventoryFixture.open(directory);
    admission = SqliteParentCustodyAdmission(
      directory: () async => directory.path,
      mayCreate: true,
      waitLimit: const Duration(milliseconds: 100),
    );
    native = _Native();
    accounts = WalletProvisioning.open(
      inventory: fixture.inventory,
      native: native,
      resume: () async => const Ok(null),
      properties: const [],
    );
    settings = _Settings();
    references = SeedReferences.forInventory(
      fixture.inventory,
      admission: admission,
      backupVerification: FakeInventoryBackups(verified: {parent}),
    );
    importer = importingWith(admission);
  });

  tearDown(() async {
    await fixture.close();
    await log.flush();
    directory.deleteSync(recursive: true);
  });

  test(
    'delete reimport delete removes the seed through the custody stages',
    () async {
      expect(
        await importer.execute(
          mnemonicWords: words,
          language: Language.english,
        ),
        isA<Ok<void, ImportMnemonicFailure>>(),
      );
      expect(
        await deleteWallet((await rows()).single.id),
        isA<Ok<void, Failure>>(),
      );
      expect((await secrets.exists(parent) as Ok).value, isFalse);
      expect(
        await importer.execute(
          mnemonicWords: words,
          language: Language.english,
        ),
        isA<Ok<void, ImportMnemonicFailure>>(),
      );
      expect(
        await deleteWallet((await rows()).single.id),
        isA<Ok<void, Failure>>(),
      );
      expect(await rows(), isEmpty);
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
        isA<Ok<void, ImportMnemonicFailure>>(),
      );
      expect(await rows(), hasLength(1));
      final result = await admission.runExclusive<ParentCustodyState>(
        parent,
        (lease) async => lease.readState(),
      );
      expect((result as Ok).value, ParentCustodyState.ready);
    },
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
      expect(await importing, isA<Ok<void, ImportMnemonicFailure>>());
      final state = await admission.runExclusive<ParentCustodyState>(
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
      expect(await rows(), isEmpty);
      finish.complete();
      expect(await deletion, isA<Ok<void, ParentCustodyFailure>>());
      expect(await importing, isA<Err<void, ImportMnemonicFailure>>());
      expect(native.creates, 0);
      expect(await rows(), isEmpty);
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
      expect(result, isA<Err<void, ImportMnemonicFailure>>());
      expect(native.creates, 0);
      expect(await rows(), isEmpty);
      expect((await secrets.exists(parent) as Ok).value, isFalse);
    },
  );

  test('real passphrase import cannot become a default wallet', () async {
    final result = await importer.execute(
      mnemonicWords: words,
      language: Language.english,
      passphrase: 'TREZOR',
    );
    expect(result, isA<Ok<void, ImportMnemonicFailure>>());
    expect((await rows()).single.isDefault, isFalse);
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
        expect(await rows(), isEmpty);
        expect((await secrets.exists(parent) as Ok).value, isTrue);
        expect(state.existsSync(), corrupt);
        if (corrupt) expect(state.readAsBytesSync(), [1, 2, 3]);
      },
    );
  }

  test('orphan cleanup reports a tombstone refusal distinctly', () async {
    expect(
      await importer.execute(mnemonicWords: words, language: Language.english),
      isA<Ok<void, ImportMnemonicFailure>>(),
    );
    expect(
      await admission.runExclusive<void>(
        parent,
        (lease) async => lease.markDeleting(),
      ),
      isA<Ok<void, ParentCustodyFailure>>(),
    );
    final cleanup = await deleteWallet((await rows()).single.id);
    expect(
      (cleanup as Err).failure,
      isA<ParentCustodyStateFailure>(),
      reason: 'the tombstone is distinct from an unreadable reference set',
    );
    expect(await rows(), isEmpty);
    expect((await secrets.exists(parent) as Ok).value, isTrue);
  });
}
