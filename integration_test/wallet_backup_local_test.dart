import 'dart:io';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_descriptor_service.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';

import '../test/features/bullvault/bullvault_test_fixture.dart';

/// Run `publish` and then `recover` on separate fresh disposable app installs,
/// retaining only the local server's database between phases. Both use public
/// fixtures and no funds. This test never clears app or server data itself.
Future<void> main({bool isInitialized = false}) async {
  const phase = String.fromEnvironment('BULL_LOCAL_METADATA_PHASE');
  const enabled = phase == 'publish' || phase == 'recover';
  const localOrigin = 'http://127.0.0.1:8235';
  TestWidgetsFlutterBinding.ensureInitialized();
  if (enabled) {
    // Check before Bull.init can start background backup work. Do not run
    // this write-capable test on a configured application or remote server.
    if (isInitialized || walletBackupDefaultServerUrl != localOrigin) {
      throw StateError('Requires a standalone local-server test build');
    }
    final directory = await getApplicationDocumentsDirectory();
    final database = File(
      p.join(directory.path, '${SqliteDatabase.name}.sqlite'),
    );
    if (await database.exists()) {
      throw StateError('Requires a fresh disposable app installation');
    }
    await Bull.init();
  }

  test(
    'local server $phase preserves a BullVault and wallet metadata',
    () async {
      final wallets = locator<WalletRepository>();
      final backup = locator<WalletBackupFacade>();
      final vaults = locator<BullVaultFacade>();
      final labels = locator<LabelsFacade>();
      expect(await wallets.getStoredWalletIds(), isEmpty);
      expect((await labels.fetchAllStrict() as Ok).value, isEmpty);
      expect((await vaults.listRecords() as Ok).value, isEmpty);

      final restored = await locator<RestoreVaultUsecase>().execute(
        decryptedVault: DecryptedVault(
          mnemonic: [...List.filled(11, 'abandon'), 'about'],
        ),
      );
      expect(
        restored,
        isA<Ok<List<WalletPreferences>, RecoverBullCoreFailure>>(),
      );
      final created =
          (restored as Ok<List<WalletPreferences>, RecoverBullCoreFailure>)
              .value;
      expect(created, hasLength(2));
      final bitcoin = (await wallets.getWallets(
        onlyDefaults: true,
      )).singleWhere((wallet) => wallet.isBitcoin);
      const walletLabel = 'Recovered local mobile wallet';
      const vaultLabel = 'Local inheritance vault';
      const transactionLabel = 'Synthetic recovery label';
      final transactionId = List.filled(32, '11').join();
      final package = testBullVaultRecoveryPackage(includesInheritance: true);

      expect(await backup.setServer(localOrigin), isA<Ok>());
      if (phase == 'publish') {
        final source = vaults.encodeRecoveryPackage(package);
        expect(vaults.decodeRecoveryPackage(source), isNotNull);
        expect(bitcoin.network, package.policy.network);
        final seedResult = await locator<GetDefaultSeedUsecase>().execute();
        expect(seedResult, isA<Ok<Seed, SeedFailure>>());
        final descriptorService = locator<BullVaultDescriptorService>();
        expect(
          descriptorService.matchesPolicyDescriptor(package.policy),
          isTrue,
        );
        expect(
          descriptorService.matchesEverydaySeed(
            package.policy,
            (seedResult as Ok<Seed, SeedFailure>).value,
          ),
          isTrue,
        );
        final imported = await vaults.restoreFromRecoveryPackage(
          source: source,
          label: vaultLabel,
        );
        expect(
          imported,
          isA<Ok<BullVaultRestoreResult, BullVaultFailure>>(),
          reason: switch (imported) {
            Err(:final failure) => failure.runtimeType.toString(),
            Ok() => null,
          },
        );
        await locator<WalletFacade>().updateWalletLabel(
          walletId: bitcoin.id,
          label: walletLabel,
        );
        expect(
          await labels.store(
            NewLabel.tx(transactionId: transactionId, label: transactionLabel),
          ),
          isA<Ok>(),
        );
      } else {
        // Nothing but the restored Mobile Key exists before server recovery.
        expect((await vaults.listRecords() as Ok).value, isEmpty);
        expect((await labels.fetchAllStrict() as Ok).value, isEmpty);
        expect(bitcoin.label, isNot(walletLabel));
      }

      expect(
        await backup.setEnabled(
          true,
          defaultCreatedWalletPreferences: phase == 'recover' ? created : [],
        ),
        isA<Ok<void, WalletBackupFailure>>(),
      );
      // Flush any revision committed while the initial publication ran.
      expect(await backup.backupNow(), isA<Ok<void, WalletBackupFailure>>());

      final recordsResult = await vaults.listRecords();
      expect(recordsResult, isA<Ok<List<BullVaultRecord>, BullVaultFailure>>());
      final records =
          (recordsResult as Ok<List<BullVaultRecord>, BullVaultFailure>).value;
      expect(records, hasLength(1));
      final record = records.single;
      expect(record.lineageId, package.policy.lineageId);
      expect(
        record.recoveryPackage.policy.descriptor,
        package.policy.descriptor,
      );
      expect(record.recoveryPackage.policy.inheritanceKey, isNotNull);
      expect(await wallets.getStoredWalletIds(), hasLength(3));
      final recoveredWallets = await wallets.getWallets();
      expect(
        recoveredWallets.singleWhere((wallet) => wallet.id == bitcoin.id).label,
        walletLabel,
      );
      expect(
        recoveredWallets
            .singleWhere((wallet) => wallet.id == record.walletId)
            .label,
        vaultLabel,
      );
      final recoveredLabels = await labels.fetchAllStrict();
      expect(recoveredLabels, isA<Ok<List<Label>, LabelFailure>>());
      final label =
          (recoveredLabels as Ok<List<Label>, LabelFailure>).value.single;
      expect(label.reference, transactionId);
      expect(label.label, transactionLabel);

      final remote = await backup.fetchRemoteContents();
      expect(remote, isA<Ok<WalletBackupContents?, WalletBackupFailure>>());
      final contents =
          (remote as Ok<WalletBackupContents?, WalletBackupFailure>).value!;
      expect(contents.labelCount, 1);
      expect(contents.vaults, hasLength(1));
      expect(contents.vaults.single.walletRef, record.walletId);
      expect(contents.vaults.single.descriptor, package.policy.descriptor);
      expect(contents.vaults.single.label, vaultLabel);
      final stateResult = await backup.watchState().first;
      expect(stateResult, isA<Ok<WalletBackupState, WalletBackupFailure>>());
      final state =
          (stateResult as Ok<WalletBackupState, WalletBackupFailure>).value;
      expect(state.enabled, isTrue);
      expect(state.recoveryBlocked, isFalse);
      expect(state.lastSucceededAt, isNotNull);
      expect(state.remoteCheckpoint, isNotNull);
    },
    skip: enabled
        ? null
        : 'Requires BULL_LOCAL_METADATA_PHASE=publish or recover, a fresh app and a local server',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
