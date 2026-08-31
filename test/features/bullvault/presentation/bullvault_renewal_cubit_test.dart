import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_previous_vault.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/cancel_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/renew_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_migration_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_renewal_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_renewal_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core_test/wallet/bdk_wallet_test_fixture.dart';

class _MockLoadRenewal extends Mock implements LoadBullVaultRenewalUsecase {}

class _MockRenew extends Mock implements RenewBullVaultUsecase {}

class _MockActivate extends Mock implements ActivateBullVaultRenewalUsecase {}

class _MockCancel extends Mock implements CancelBullVaultRenewalUsecase {}

class _MockUpdateSetup extends Mock implements UpdateBullVaultSetupUsecase {}

class _MockWatchMigration extends Mock
    implements WatchBullVaultMigrationUsecase {}

class _MockEncodeRecoveryPackage extends Mock
    implements EncodeBullVaultRecoveryPackageUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      BullVaultRenewRequest(
        walletId: 'fallback-wallet',
        label: 'Fallback',
        schedule: BullVaultSchedule.standardWithoutInheritance,
        timeReference: BullVaultTimeReference(
          deviceTime: DateTime.utc(2027),
          chainHeight: 3_000_000,
          medianTimePast:
              DateTime.utc(
                2027,
              ).subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000,
        ),
      ),
    );
  });

  test(
    'restores pending setup without requiring a chain-time lookup',
    () async {
      final load = _MockLoadRenewal();
      final watchMigration = _MockWatchMigration();
      final details = _details();
      final renewal = _renewal(details.record);
      final encodeRecoveryPackage = _MockEncodeRecoveryPackage();
      when(() => load.execute(details.record.walletId)).thenAnswer(
        (_) async =>
            Ok(BullVaultRenewalLoad(details: details, renewal: renewal)),
      );
      when(
        () =>
            encodeRecoveryPackage.execute(renewal.replacement.recoveryPackage),
      ).thenReturn('{}');
      when(
        () => watchMigration.execute(
          previousWalletId: 'retired-wallet',
          migrationAddress: details.migrationAddress!,
        ),
      ).thenAnswer((_) => Stream.value(const Ok('migration-txid')));
      final cubit = BullVaultRenewalCubit(
        load,
        _MockRenew(),
        _MockActivate(),
        _MockCancel(),
        _MockUpdateSetup(),
        watchMigration,
        encodeRecoveryPackage,
        walletId: details.record.walletId,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.renewal, same(renewal));
      expect(cubit.state.details, same(details));
      expect(cubit.state.step, BullVaultRenewalStep.recoveryPackage);
      expect(cubit.state.isLoading, isFalse);
      expect(
        cubit.state.migrationTransactionIds['retired-wallet'],
        'migration-txid',
      );
      verify(() => load.execute(details.record.walletId)).called(1);
      await cubit.close();
    },
  );

  test('returns to renewal review after cancellation', () async {
    final load = _MockLoadRenewal();
    final cancel = _MockCancel();
    final watchMigration = _MockWatchMigration();
    final encode = _MockEncodeRecoveryPackage();
    final details = _details();
    final renewal = _renewal(details.record);
    var loadCount = 0;
    when(() => load.execute(details.record.walletId)).thenAnswer((_) async {
      loadCount++;
      return Ok(
        BullVaultRenewalLoad(
          details: details,
          renewal: loadCount == 1 ? renewal : null,
          timeReference: loadCount == 1
              ? null
              : BullVaultTimeReference(
                  deviceTime: DateTime.utc(2028),
                  chainHeight: 3_100_000,
                  medianTimePast:
                      DateTime.utc(2028)
                          .subtract(const Duration(hours: 1))
                          .millisecondsSinceEpoch ~/
                      1000,
                ),
        ),
      );
    });
    when(
      () => encode.execute(renewal.replacement.recoveryPackage),
    ).thenReturn('{}');
    when(
      () => cancel.execute(
        previousWalletId: details.record.walletId,
        replacementWalletId: renewal.replacement.wallet.id,
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => watchMigration.execute(
        previousWalletId: 'retired-wallet',
        migrationAddress: details.migrationAddress!,
      ),
    ).thenAnswer((_) => const Stream.empty());
    final cubit = BullVaultRenewalCubit(
      load,
      _MockRenew(),
      _MockActivate(),
      cancel,
      _MockUpdateSetup(),
      watchMigration,
      encode,
      walletId: details.record.walletId,
    );

    await cubit.load();
    await cubit.cancel();

    expect(cubit.state.step, BullVaultRenewalStep.review);
    expect(cubit.state.renewal, isNull);
    expect(cubit.state.recoveryPackageContent, isNull);
    verify(
      () => cancel.execute(
        previousWalletId: details.record.walletId,
        replacementWalletId: renewal.replacement.wallet.id,
      ),
    ).called(1);
    await cubit.close();
  });

  test('prepares, confirms, and activates a renewal', () async {
    final load = _MockLoadRenewal();
    final renew = _MockRenew();
    final activate = _MockActivate();
    final update = _MockUpdateSetup();
    final watchMigration = _MockWatchMigration();
    final encode = _MockEncodeRecoveryPackage();
    final details = _details();
    final renewal = _renewal(details.record);
    final reference = BullVaultTimeReference(
      deviceTime: DateTime.utc(2028),
      chainHeight: 3_100_000,
      medianTimePast:
          DateTime.utc(
            2028,
          ).subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    );
    when(() => load.execute(details.record.walletId)).thenAnswer(
      (_) async =>
          Ok(BullVaultRenewalLoad(details: details, timeReference: reference)),
    );
    when(() => renew.execute(any())).thenAnswer((_) async => Ok(renewal));
    when(
      () => encode.execute(renewal.replacement.recoveryPackage),
    ).thenReturn('{}');
    when(
      () => watchMigration.execute(
        previousWalletId: 'retired-wallet',
        migrationAddress: details.migrationAddress!,
      ),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => update.execute(
        walletId: renewal.replacement.wallet.id,
        completedHardwareSignerId: 'cold',
      ),
    ).thenAnswer(
      (_) async => Ok(
        renewal.replacement.record.copyWith(
          completedHardwareSignerIds: const {'cold'},
        ),
      ),
    );
    when(
      () => update.execute(
        walletId: renewal.replacement.wallet.id,
        recoveryPackageConfirmed: true,
      ),
    ).thenAnswer(
      (_) async => Ok(
        renewal.replacement.record.copyWith(
          completedHardwareSignerIds: const {'cold'},
          recoveryPackageConfirmed: true,
        ),
      ),
    );
    when(
      () => activate.execute(
        previousWalletId: details.record.walletId,
        replacementWalletId: renewal.replacement.wallet.id,
      ),
    ).thenAnswer((_) async => const Ok(null));
    final cubit = BullVaultRenewalCubit(
      load,
      renew,
      activate,
      _MockCancel(),
      update,
      watchMigration,
      encode,
      walletId: details.record.walletId,
    );

    await cubit.load();
    await cubit.renew(label: 'Renewed BullVault');
    expect(cubit.state.step, BullVaultRenewalStep.recoveryPackage);

    cubit.markRecoveryPackageExported();
    await cubit.confirmRecoveryPackage();
    cubit.continueSetup();
    expect(cubit.state.step, BullVaultRenewalStep.hardwareSetup);

    await cubit.completeSigner('cold');
    cubit.continueSetup();
    expect(cubit.state.step, BullVaultRenewalStep.activation);

    await cubit.activate();

    expect(cubit.state.renewal, same(renewal));
    expect(cubit.state.completedSignerIds, {'cold'});
    expect(cubit.state.recoveryPackageConfirmed, isTrue);
    expect(cubit.state.isActivated, isTrue);
    expect(cubit.state.step, BullVaultRenewalStep.complete);
    await cubit.close();
  });
}

BullVaultDetails _details() {
  final policy = _policy();
  final record = _record(
    policy: policy,
    walletId: 'active-wallet',
    status: BullVaultLifecycleStatus.active,
  );
  final previous = _record(
    policy: policy,
    walletId: 'retired-wallet',
    status: BullVaultLifecycleStatus.migrating,
  );
  return BullVaultDetails(
    record: record,
    policy: policy,
    timeUntilFirstRecovery: const Duration(days: 365),
    showEarlyRenewalWarning: false,
    migrationAddress: 'tb1qmigration',
    previousVaults: [
      BullVaultPreviousVault(
        record: previous,
        wallet: _wallet('retired-wallet', isHidden: true),
      ),
    ],
  );
}

BullVaultRenewResult _renewal(BullVaultRecord previous) {
  final policy = _policy(lineageId: previous.lineageId, vaultGeneration: 1);
  final wallet = _wallet('replacement-wallet', isHidden: true);
  final record = _record(
    policy: policy,
    walletId: wallet.id,
    previousWalletId: previous.walletId,
    status: BullVaultLifecycleStatus.pending,
  );
  final recovery = BullVaultRecoveryPackage(
    previousVaultId: previous.walletId,
    policy: policy,
  );
  return BullVaultRenewResult(
    previous: previous,
    replacement: BullVaultCreateResult(
      wallet: wallet,
      policy: policy,
      record: record,
      recoveryPackage: recovery,
    ),
  );
}

BullVaultRecord _record({
  required BullVaultPolicy policy,
  required String walletId,
  String? previousWalletId,
  required BullVaultLifecycleStatus status,
}) => BullVaultRecord(
  walletId: walletId,
  lineageId: policy.lineageId,
  vaultGeneration: policy.vaultGeneration,
  mobileAccount: 0,
  birthHeight: policy.birthHeight,
  recoveryPackage: BullVaultRecoveryPackage(
    previousVaultId: previousWalletId,
    policy: policy,
  ),
  previousVaultId: previousWalletId,
  status: status,
  createdAt: DateTime.utc(2027),
);

BullVaultPolicy _policy({String? lineageId, int vaultGeneration = 0}) {
  final createdAt = DateTime.utc(2027);
  return BullVaultPolicy.build(
    lineageId: lineageId,
    vaultGeneration: vaultGeneration,
    network: Network.bitcoinTestnet,
    descriptor: 'tr(bullvault-$vaultGeneration)',
    protection: BullVaultProtection.standard,
    everydayKey: _signer(BullVaultSignerRole.everyday, 0),
    coldKey: _signer(BullVaultSignerRole.cold, 1),
    secondColdKey: null,
    inheritanceKey: null,
    schedule: BullVaultSchedule.standardWithoutInheritance,
    timeReference: BullVaultTimeReference(
      deviceTime: createdAt,
      chainHeight: 3_000_000,
      medianTimePast:
          createdAt.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    ),
  );
}

BullVaultSignerKey _signer(BullVaultSignerRole role, int mnemonicIndex) {
  final derived = deriveSignerKeys(testMnemonics[mnemonicIndex]);
  return BullVaultSignerKey(
    role: role,
    accountKey: WalletDescriptorKey(
      id: '${role.name}-account',
      signerId: role.name,
      masterFingerprint: derived.fingerprint,
      xpubFingerprint: derived.fingerprint,
      xpub: derived.xpub.split(']').last,
      derivationPath: "m/48'/1'/0'/2'",
    ),
    signer: SignerEntity.remote,
    signerDevice: null,
  );
}

Wallet _wallet(String id, {required bool isHidden}) => Wallet(
  origin: id,
  network: Network.bitcoinTestnet,
  signers: [
    WalletSigner.single(
      id: 'cold',
      masterFingerprint: 'f6472bcf',
      xpubFingerprint: 'f6472bcf',
      xpub: deriveSignerKeys(testMnemonics[0]).xpub.split(']').last,
      signer: SignerEntity.remote,
      signerDevice: null,
    ),
  ],
  scriptType: null,
  publicDescriptor: 'tr(bullvault)',
  balanceSat: BigInt.zero,
  isHidden: isHidden,
);
