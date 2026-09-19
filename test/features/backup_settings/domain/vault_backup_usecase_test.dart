import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_vault_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_status.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault/bullvault_test_fixture.dart';
import '../../wallet_backup/backup_snapshot_fixture.dart';

final date = DateTime.utc(2026, 9, 18, 15);

class _Vaults extends Fake implements BullVaultFacade {
  final records = <String, BullVaultRecord>{};
  final reads = <String>[];
  final receipts = <(String, BullVaultBackupTestKind, String)>[];
  final codec = testBullVaultRecoveryPackageCodec();
  BullVaultFailure? receiptFailure;
  Result<String?, BullVaultFailure> picked = const Ok(null);
  int picks = 0;
  @override
  Future<Result<String?, BullVaultFailure>> pickRecoveryFile() async {
    picks++;
    return picked;
  }

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getRecord(
    String id,
  ) async {
    reads.add(id);
    return Ok(records[id]);
  }

  @override
  String encodeRecoveryPackage(BullVaultRecoveryPackage package) =>
      codec.encode(package);
  @override
  Result<BullVaultRecoveryPackage, BullVaultFailure> decodeRecoveryPackage(
    String source,
  ) => Ok(codec.decode(source));
  @override
  Future<Result<DateTime, BullVaultFailure>> verifyBackup({
    required BullVaultRecord expected,
    required String source,
    BullVaultBackupTestKind kind = BullVaultBackupTestKind.descriptor,
  }) async {
    receipts.add((expected.walletId, kind, source));
    return receiptFailure == null ? Ok(date) : Err(receiptFailure!);
  }
}

class _Backups extends Fake implements WalletBackupFacade {
  WalletBackupControl control = const WalletBackupControl(enabled: true);
  late Result<WalletBackupInspection, WalletBackupFailure> inspection;
  int fetches = 0;
  @override
  Future<Result<WalletBackupControl, WalletBackupFailure>> getControl() async =>
      Ok(control);
  @override
  Future<Result<WalletBackupInspection, WalletBackupFailure>> inspect({
    String? words,
  }) async {
    fetches++;
    return inspection;
  }
}

class _Status extends Mock implements GetWalletsUsecase {}

class _Wallet extends Mock implements Wallet {}

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final old = testBullVaultCreateResult(walletId: 'local-old').record;
  final selected = testBullVaultCreateResult(
    walletId: 'selected',
    generation: 1,
    lineageId: old.lineageId,
    previousVaultId: old.walletId,
  ).record;
  late _Vaults vaults;
  late _Backups backups;
  late _Status status;
  late LoadVaultBackupUsecase load;
  late CheckVaultServerBackupUsecase check;

  WalletBackupInspection inspection(List<BullVaultRecord> records) {
    final base = backupSnapshotFixture(credential, populated: false);
    final entries = [
      for (final record in records)
        BullVaultBackupEntry(
          reference: 'portable-${record.walletId}',
          status: record.status,
          recoveryPackage: vaults.codec.decode(
            vaults.codec.encode(
              BullVaultRecoveryPackage(
                policy: record.recoveryPackage.policy,
                previousVaultId: record.previousVaultId == null
                    ? null
                    : 'portable-${record.previousVaultId}',
              ),
            ),
          ),
        ),
    ];
    return WalletBackupInspection(
      identity: credential.serverPublicKey,
      head: WalletBackupRemoteHead(
        generation: 1,
        etag: 'a' * 64,
        ciphertext: WalletBackupCiphertext(List.filled(64, 1)),
      ),
      snapshot: WalletBackupSnapshot(
        manifest: KeychainManifest(
          sourceFingerprint: base.manifest.sourceFingerprint,
          wallets: [
            for (final entry in entries)
              BackupWallet(
                reference: entry.reference,
                network: entry.recoveryPackage.policy.network,
                publicDescriptor: entry.recoveryPackage.policy.descriptor,
                signers: [],
                isDefault: false,
                isHidden: false,
                label: 'Vault',
              ),
          ],
          derivations: [],
          nostrKeys: [],
          backupIdentities: base.manifest.backupIdentities,
        ),
        metadata: base.metadata,
        vaults: entries,
      ),
    );
  }

  setUp(() {
    vaults = _Vaults()
      ..records.addAll({old.walletId: old, selected.walletId: selected});
    backups = _Backups()..inspection = Ok(inspection([old, selected]));
    status = _Status();
    final wallet = _Wallet();
    when(
      () => wallet.masterFingerprint,
    ).thenReturn(selected.mobileSeedFingerprint!);
    when(
      () => status.execute(
        onlyDefaults: true,
        onlyBitcoin: true,
        includeHidden: true,
      ),
    ).thenAnswer((_) async => [wallet]);
    load = LoadVaultBackupUsecase(
      vaults,
      backups,
      GetWalletRecoveryStatusUsecase(status),
    );
    check = CheckVaultServerBackupUsecase(vaults, backups);
  });

  test(
    'load reads the selected record once and does not inspect or derive remotely',
    () async {
      final result = await load.execute(selected.walletId);
      final value =
          (result as Ok<VaultBackupStatus, BackupSettingsFailure>).value;
      expect(value.record, same(selected));
      expect(value.canRevealWords, isTrue);
      expect(vaults.reads, [selected.walletId]);
      expect(backups.fetches, 0);
      expect(vaults.receipts, isEmpty);
    },
  );
  test(
    'missing, foreign and inaccessible origins never offer device words',
    () async {
      final foreign = _Wallet();
      when(() => foreign.masterFingerprint).thenReturn('deadbeef');
      when(
        () => status.execute(
          onlyDefaults: true,
          onlyBitcoin: true,
          includeHidden: true,
        ),
      ).thenAnswer((_) async => [foreign]);
      expect(
        (await load.execute(selected.walletId)
                as Ok<VaultBackupStatus, BackupSettingsFailure>)
            .value
            .canRevealWords,
        isFalse,
      );
      when(
        () => status.execute(
          onlyDefaults: true,
          onlyBitcoin: true,
          includeHidden: true,
        ),
      ).thenThrow(GetWalletsException('locked'));
      expect(
        (await load.execute(selected.walletId)
                as Ok<VaultBackupStatus, BackupSettingsFailure>)
            .value
            .canRevealWords,
        isFalse,
      );
      final external = testBullVaultCreateResult(
        walletId: 'external',
        usesBullMobile: false,
      ).record;
      vaults.records[external.walletId] = external;
      expect(
        (await load.execute(external.walletId)
                as Ok<VaultBackupStatus, BackupSettingsFailure>)
            .value
            .canRevealWords,
        isFalse,
      );
      expect(
        await load.execute('missing'),
        isA<Err<VaultBackupStatus, BackupSettingsFailure>>(),
      );
    },
  );
  test(
    'renewed vault uses portable predecessors, one inspection and only its server receipt',
    () async {
      final fetched =
          (backups.inspection
                  as Ok<WalletBackupInspection, WalletBackupFailure>)
              .value;
      final result = await check.execute(selected);
      final value =
          (result as Ok<VaultBackupCheck, BackupSettingsFailure>).value;
      expect(value.inspection, same(fetched));
      expect(value.record.serverTestedAt, date);
      expect(value.record.descriptorTestedAt, selected.descriptorTestedAt);
      expect(
        value.record.recoveryPackageConfirmed,
        selected.recoveryPackageConfirmed,
      );
      expect(backups.fetches, 1);
      expect(vaults.reads, [old.walletId]);
      expect(vaults.receipts.single.$1, selected.walletId);
      expect(vaults.receipts.single.$2, BullVaultBackupTestKind.server);
    },
  );
  test(
    'first generation needs no record reload for a successful check',
    () async {
      backups.inspection = Ok(inspection([old]));
      expect(
        await check.execute(old),
        isA<Ok<VaultBackupCheck, BackupSettingsFailure>>(),
      );
      expect(vaults.reads, isEmpty);
      expect(backups.fetches, 1);
    },
  );
  test(
    'other network, another policy and changed lifecycle cannot create a receipt',
    () async {
      final other = testBullVaultCreateResult(
        walletId: 'selected',
        generation: 1,
        lineageId: old.lineageId,
        previousVaultId: old.walletId,
        includesInheritance: true,
      ).record;
      for (final copy in [
        inspection([]),
        inspection([old, other]),
        inspection([old, selected.copyWith(status: .cancelled)]),
        inspection([
          testBullVaultCreateResult(network: Network.bitcoinTestnet).record,
        ]),
      ]) {
        backups.inspection = Ok(copy);
        expect(
          await check.execute(selected),
          isA<Err<VaultBackupCheck, BackupSettingsFailure>>(),
        );
      }
      expect(vaults.receipts, isEmpty);
    },
  );
  test('missing or mismatched local predecessor blocks the receipt', () async {
    vaults.records.remove(old.walletId);
    expect(
      await check.execute(selected),
      isA<Err<VaultBackupCheck, BackupSettingsFailure>>(),
    );
    vaults.records[old.walletId] = testBullVaultCreateResult(
      walletId: old.walletId,
      includesInheritance: true,
    ).record;
    expect(
      await check.execute(selected),
      isA<Err<VaultBackupCheck, BackupSettingsFailure>>(),
    );
    expect(vaults.receipts, isEmpty);
  });
  test(
    'server failure and a concurrent selected-record change never become a successful check',
    () async {
      backups.inspection = const Err(WalletBackupNetworkFailure());
      expect(
        await check.execute(selected),
        isA<Err<VaultBackupCheck, BackupSettingsFailure>>(),
      );
      expect(vaults.receipts, isEmpty);
      backups.inspection = Ok(inspection([old, selected]));
      vaults.receiptFailure = const BullVaultBackupMismatchFailure();
      expect(
        await check.execute(selected),
        isA<Err<VaultBackupCheck, BackupSettingsFailure>>(),
      );
      expect(selected.serverTestedAt, isNull);
    },
  );
  test(
    'incomplete recovery remains visible after a valid package check',
    () async {
      backups.control = const WalletBackupControl(
        enabled: true,
        recoveryIncomplete: true,
      );
      final loaded =
          (await load.execute(selected.walletId)
                  as Ok<VaultBackupStatus, BackupSettingsFailure>)
              .value;
      expect(loaded.control.recoveryIncomplete, isTrue);
      final result = await check.execute(selected);
      expect(result, isA<Ok<VaultBackupCheck, BackupSettingsFailure>>());
      expect(backups.control.recoveryIncomplete, isTrue);
    },
  );
  test(
    'manual import cancels without a receipt and verifies one picked file',
    () async {
      final manual = VerifyVaultDescriptorBackupUsecase(vaults);
      expect(
        (await manual.execute(selected) as Ok<DateTime?, BackupSettingsFailure>)
            .value,
        isNull,
      );
      expect(vaults.receipts, isEmpty);
      vaults.picked = const Ok('matching-file');
      expect(
        (await manual.execute(selected) as Ok<DateTime?, BackupSettingsFailure>)
            .value,
        date,
      );
      expect(vaults.picks, 2);
      expect(vaults.receipts.single, (
        selected.walletId,
        BullVaultBackupTestKind.descriptor,
        'matching-file',
      ));
      expect(vaults.reads, isEmpty);
    },
  );
  test(
    'manual input goes directly to verification and propagates mismatch',
    () async {
      final manual = VerifyVaultDescriptorBackupUsecase(vaults);
      vaults.receiptFailure = const BullVaultBackupMismatchFailure();
      expect(
        await manual.execute(selected, source: 'wrong'),
        isA<Err<DateTime?, BackupSettingsFailure>>(),
      );
      expect(vaults.picks, 0);
      expect(vaults.receipts.single.$3, 'wrong');
    },
  );
  test(
    'missing local record and receipt storage errors are not descriptor mismatches',
    () async {
      final missing = await load.execute('missing');
      expect(
        (missing as Err<VaultBackupStatus, BackupSettingsFailure>).failure,
        isA<BackupSettingsUnexpectedFailure>(),
      );
      vaults.receiptFailure = const BullVaultBackupStatusFailure();
      final server = await check.execute(selected);
      expect(
        (server as Err<VaultBackupCheck, BackupSettingsFailure>).failure,
        isA<BackupSettingsUnexpectedFailure>(),
      );
      final manual = await VerifyVaultDescriptorBackupUsecase(
        vaults,
      ).execute(selected, source: 'valid-descriptor');
      expect(
        (manual as Err<DateTime?, BackupSettingsFailure>).failure,
        isA<BackupSettingsUnexpectedFailure>(),
      );
    },
  );
}
