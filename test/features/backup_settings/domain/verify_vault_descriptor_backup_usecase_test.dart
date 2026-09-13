import 'dart:typed_data';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/data/vault_backup_test_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/vault_backup_test_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/verify_vault_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../bullvault/bullvault_test_fixture.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';

class _Vaults extends Mock implements BullVaultFacade {}

class _Metadata extends Mock implements WalletBackupFacade {}

class _Files extends Mock implements WalletBackupFileRepository {}

class _History extends Mock implements VaultBackupTestRepository {}

class _Parser extends Fake implements BitcoinDescriptorPort {
  final bool fails;
  _Parser({this.fails = false});

  @override
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) {
    if (fails) throw const FormatException('invalid stored descriptor');
    return parseTestBullVaultDescriptor(
      descriptor: descriptor,
      network: network,
    );
  }
}

void main() {
  late _Vaults vaults;
  late _Metadata metadata;
  late _Files files;
  late VaultBackupTestRepositoryImpl history;
  late VerifyVaultDescriptorBackupUsecase verify;
  final now = DateTime.utc(2026, 9, 13, 18);
  final record = testBullVaultCreateResult(includesInheritance: true).record;
  final policy = record.recoveryPackage.policy;
  final descriptorId = VaultBackupTest.identity(
    policy.descriptor,
    policy.network.name,
  );
  final codec = testBullVaultRecoveryPackageCodec();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    vaults = _Vaults();
    metadata = _Metadata();
    files = _Files();
    history = VaultBackupTestRepositoryImpl();
    when(() => vaults.listRecords()).thenAnswer((_) async => Ok([record]));
    when(() => vaults.decodeRecoveryPackage(any())).thenAnswer((call) {
      try {
        return codec.decode(call.positionalArguments.single as String);
      } on FormatException {
        return null;
      }
    });
    when(
      () => vaults.encodeRecoveryPackage(record.recoveryPackage),
    ).thenReturn(codec.encode(record.recoveryPackage));
    verify = VerifyVaultDescriptorBackupUsecase(
      vaults,
      metadata,
      _Parser(),
      history,
      files,
      now: () => now,
    );
  });

  Future<Map<VaultBackupSource, DateTime>> dates([String? id]) async =>
      (await history.load(id ?? descriptorId)
              as Ok<Map<VaultBackupSource, DateTime>, BackupSettingsFailure>)
          .value;

  test(
    'manual descriptor canonicalization records a genuine matching import',
    () async {
      final withoutChecksum = policy.descriptor.split('#').first;
      expect(
        await verify.verifyManual(record.walletId, withoutChecksum),
        isA<Ok<bool, BackupSettingsFailure>>().having(
          (r) => r.value,
          'matched',
          true,
        ),
      );
      expect(await dates(), {VaultBackupSource.manual: now});
      verifyZeroInteractions(metadata);
    },
  );

  test(
    'recovery package verifies but export alone never records a test',
    () async {
      final inspected =
          (await verify.load(record.walletId)
                  as Ok<VaultBackupInspection, BackupSettingsFailure>)
              .value;
      expect(verify.export(inspected), codec.encode(record.recoveryPackage));
      expect(await dates(), isEmpty);
      await verify.verifyManual(
        record.walletId,
        codec.encode(record.recoveryPackage),
      );
      expect(await dates(), {VaultBackupSource.manual: now});
    },
  );

  test('a renewal descriptor cannot certify the older generation', () async {
    final replacement = testBullVaultRecoveryPackage(
      includesInheritance: true,
      generation: 1,
      lineageId: policy.lineageId,
    );
    expect(
      await verify.verifyManual(record.walletId, replacement.policy.descriptor),
      isA<Ok<bool, BackupSettingsFailure>>().having(
        (r) => r.value,
        'matched',
        false,
      ),
    );
    expect(await dates(), isEmpty);
    expect(
      await dates(
        VaultBackupTest.identity(
          replacement.policy.descriptor,
          replacement.policy.network.name,
        ),
      ),
      isEmpty,
    );
  });

  test(
    'wrong network and malformed input preserve previous successful date',
    () async {
      await verify.verifyManual(record.walletId, policy.descriptor);
      final foreign = testBullVaultRecoveryPackage(
        includesInheritance: true,
        network: Network.bitcoinTestnet,
      );
      expect(
        await verify.verifyManual(record.walletId, codec.encode(foreign)),
        isA<Err>(),
      );
      expect(
        await verify.verifyManual(record.walletId, 'not a descriptor'),
        isA<Err>(),
      );
      expect(await dates(), {VaultBackupSource.manual: now});
    },
  );

  test('file picker cancellation has no result and no write', () async {
    when(() => files.pick(maximumBytes: any(named: 'maximumBytes'))).thenAnswer(
      (_) async => const Ok<Uint8List?, BackupSettingsFailure>(null),
    );
    expect(
      await verify.importFile(record.walletId),
      isA<Ok<bool?, BackupSettingsFailure>>().having(
        (r) => r.value,
        'cancelled',
        null,
      ),
    );
    expect(await dates(), isEmpty);
  });

  test(
    'stored descriptor parse failure is typed and never starts a fetch',
    () async {
      final usecase = VerifyVaultDescriptorBackupUsecase(
        vaults,
        metadata,
        _Parser(fails: true),
        history,
        files,
      );
      expect(
        await usecase.verifyMetadata(record.walletId),
        isA<Err<bool, BackupSettingsFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<BackupSettingsInvalidFileFailure>(),
        ),
      );
      verifyZeroInteractions(metadata);
      expect(await dates(), isEmpty);
    },
  );

  test('remote read-back certifies only the metadata source', () async {
    when(() => metadata.fetchRemoteContents()).thenAnswer(
      (_) async => Ok(
        WalletBackupContents(
          vaults: [
            WalletBackupVaultSummary(
              walletRef: record.walletId,
              status: record.status.name,
              network: policy.network,
              lineageId: policy.lineageId,
              vaultGeneration: policy.vaultGeneration,
              descriptor: policy.descriptor,
              birthHeight: policy.birthHeight,
              recoveryPackage: codec.encode(record.recoveryPackage),
            ),
          ],
          labelCount: 0,
          frozenCoinCount: 0,
          walletPreferenceCount: 0,
        ),
      ),
    );
    expect(
      await verify.verifyMetadata(record.walletId),
      isA<Ok<bool, BackupSettingsFailure>>().having(
        (r) => r.value,
        'matched',
        true,
      ),
    );
    expect(await dates(), {VaultBackupSource.metadata: now});
  });

  test(
    'missing remote descriptor never erases or advances a prior date',
    () async {
      await history.record(
        VaultBackupTest(
          descriptorId: descriptorId,
          source: VaultBackupSource.metadata,
          verifiedAt: now.subtract(const Duration(days: 2)),
        ),
      );
      when(
        () => metadata.fetchRemoteContents(),
      ).thenAnswer((_) async => const Ok(null));
      expect(
        await verify.verifyMetadata(record.walletId),
        isA<Ok<bool, BackupSettingsFailure>>().having(
          (r) => r.value,
          'matched',
          false,
        ),
      );
      expect(
        (await dates())[VaultBackupSource.metadata],
        now.subtract(const Duration(days: 2)),
      );
    },
  );

  test('storage failure is not reported as a successful backup test', () async {
    final failedHistory = _History();
    when(
      () => failedHistory.load(descriptorId),
    ).thenAnswer((_) async => const Ok({}));
    registerFallbackValue(
      VaultBackupTest(
        descriptorId: descriptorId,
        source: VaultBackupSource.manual,
        verifiedAt: now,
      ),
    );
    when(
      () => failedHistory.record(any()),
    ).thenAnswer((_) async => const Err(BackupSettingsStorageFailure()));
    final usecase = VerifyVaultDescriptorBackupUsecase(
      vaults,
      metadata,
      _Parser(),
      failedHistory,
      files,
    );
    expect(
      await usecase.verifyManual(record.walletId, policy.descriptor),
      isA<Err<bool, BackupSettingsFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<BackupSettingsStorageFailure>(),
      ),
    );
  });

  test(
    'receipt survives birthday enrichment of an identical descriptor',
    () async {
      await verify.verifyManual(record.walletId, policy.descriptor);
      final enriched = BullVaultPolicy.build(
        lineageId: policy.lineageId,
        vaultGeneration: 0,
        network: policy.network,
        descriptor: policy.descriptor,
        protection: policy.protection,
        everydayKey: policy.everydayKey,
        coldKey: policy.coldKey,
        secondColdKey: policy.secondColdKey,
        inheritanceKey: policy.inheritanceKey,
        schedule: policy.schedule!,
        timeReference: BullVaultTimeReference(
          deviceTime: policy.createdAt!,
          chainHeight: policy.birthHeight! + 1,
          medianTimePast: policy.chainMedianTimePast!,
        ),
      );
      expect(enriched.id, isNot(policy.id));
      final updated = BullVaultRecord(
        walletId: record.walletId,
        lineageId: enriched.lineageId,
        vaultGeneration: record.vaultGeneration,
        mobileAccount: record.mobileAccount,
        mobileSeedFingerprint: record.mobileSeedFingerprint,
        birthHeight: enriched.birthHeight,
        recoveryPackage: BullVaultRecoveryPackage(policy: enriched),
        status: record.status,
        createdAt: record.createdAt,
      );
      when(() => vaults.listRecords()).thenAnswer((_) async => Ok([updated]));
      final inspection =
          (await verify.load(record.walletId)
                  as Ok<VaultBackupInspection, BackupSettingsFailure>)
              .value;
      expect(inspection.testedAt[VaultBackupSource.manual], now);
      expect(inspection.descriptorId, descriptorId);
    },
  );

  test('independent source writes survive a new repository instance', () async {
    await Future.wait([
      history.record(
        VaultBackupTest(
          descriptorId: descriptorId,
          source: VaultBackupSource.manual,
          verifiedAt: now,
        ),
      ),
      history.record(
        VaultBackupTest(
          descriptorId: descriptorId,
          source: VaultBackupSource.metadata,
          verifiedAt: now,
        ),
      ),
    ]);
    final reloaded = await VaultBackupTestRepositoryImpl().load(descriptorId);
    expect(
      (reloaded as Ok<Map<VaultBackupSource, DateTime>, BackupSettingsFailure>)
          .value
          .keys
          .toSet(),
      {VaultBackupSource.manual, VaultBackupSource.metadata},
    );
  });

  test(
    'damaged test history cannot prevent exporting the descriptor',
    () async {
      SharedPreferences.setMockInitialValues({
        'vault_descriptor_test_v1.$descriptorId.manual': 'damaged',
      });
      final result = await verify.load(record.walletId);
      final inspection =
          (result as Ok<VaultBackupInspection, BackupSettingsFailure>).value;
      expect(inspection.historyFailure, isA<BackupSettingsStorageFailure>());
      expect(inspection.testedAt, isEmpty);
      expect(verify.export(inspection), codec.encode(record.recoveryPackage));
    },
  );
}
