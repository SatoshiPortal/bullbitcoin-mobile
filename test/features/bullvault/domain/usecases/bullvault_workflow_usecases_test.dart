import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_renewal_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault_test_fixture.dart';

class _MockSettings extends Mock implements GetSettingsUsecase {}

class _MockResumeOnboarding extends Mock
    implements ResumeBullVaultOnboardingUsecase {}

class _MockCheckBackups extends Mock
    implements CheckBullVaultMobileBackupsUsecase {}

class _MockCreateVault extends Mock implements CreateBullVaultUsecase {}

class _MockGetDetails extends Mock implements GetBullVaultDetailsUsecase {}

class _MockResumeRenewal extends Mock
    implements ResumeBullVaultRenewalUsecase {}

class _MockPrepareTime extends Mock
    implements PrepareBullVaultTimeReferenceUsecase {}

void main() {
  test('loads a pending vault with backup status for its Bull seed', () async {
    final settings = _MockSettings();
    final resume = _MockResumeOnboarding();
    final checkBackups = _MockCheckBackups();
    final created = testBullVaultCreateResult();
    when(settings.execute).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => resume.execute(created.wallet.network),
    ).thenAnswer((_) async => Ok(created));
    when(
      () => checkBackups.execute(
        created.policy.everydayKey.accountKey.masterFingerprint,
      ),
    ).thenAnswer((_) async => const Ok((physical: true, recoverBull: false)));
    final usecase = LoadBullVaultOnboardingUsecase(
      settings,
      resume,
      checkBackups,
    );

    final result = await usecase.execute();

    final loaded = (result as Ok).value;
    expect(loaded.snapshot?.result, same(created));
    expect((loaded.snapshot!.mobileBackupStatus as Ok).value.physical, isTrue);
  });

  test('creates a vault and checks its mobile-key backups', () async {
    final create = _MockCreateVault();
    final checkBackups = _MockCheckBackups();
    final created = testBullVaultCreateResult();
    final request = _createRequest();
    when(() => create.execute(request)).thenAnswer((_) async => Ok(created));
    when(
      () => checkBackups.execute(
        created.policy.everydayKey.accountKey.masterFingerprint,
      ),
    ).thenAnswer((_) async => const Ok((physical: false, recoverBull: true)));
    final usecase = CreateBullVaultOnboardingUsecase(create, checkBackups);

    final result = await usecase.execute(request);

    final snapshot = (result as Ok).value;
    expect(snapshot.result, same(created));
    expect((snapshot.mobileBackupStatus as Ok).value.recoverBull, isTrue);
  });

  test(
    'restores a pending renewal without requesting new chain time',
    () async {
      final getDetails = _MockGetDetails();
      final resume = _MockResumeRenewal();
      final prepareTime = _MockPrepareTime();
      final details = testBullVaultDetails();
      final replacement = testBullVaultCreateResult(
        walletId: 'replacement-wallet',
        previousVaultId: details.record.walletId,
        lineageId: details.record.lineageId,
        generation: 1,
      );
      final renewal = BullVaultRenewResult(
        previous: details.record,
        replacement: replacement,
      );
      when(
        () => getDetails.execute(details.record.walletId),
      ).thenAnswer((_) async => Ok(details));
      when(
        () => resume.execute(details.record.walletId),
      ).thenAnswer((_) async => Ok(renewal));
      final usecase = LoadBullVaultRenewalUsecase(
        getDetails,
        resume,
        prepareTime,
        _backupStatus(),
      );

      final result = await usecase.execute(details.record.walletId);

      final loaded = (result as Ok).value;
      expect(loaded.renewal, same(renewal));
      expect(loaded.needsInitialSetup, isTrue);
      verifyNever(
        () => prepareTime.execute(isTestnet: any(named: 'isTestnet')),
      );
    },
  );

  test('loads extra protection recovery dates from fresh chain time', () async {
    final getDetails = _MockGetDetails();
    final resume = _MockResumeRenewal();
    final prepareTime = _MockPrepareTime();
    final base = testBullVaultDetails(protection: BullVaultProtection.extra);
    final details = BullVaultDetails(
      record: base.record.copyWith(hardwareSetupComplete: true),
      policy: base.policy,
      timeUntilFirstRecovery: base.timeUntilFirstRecovery,
      showEarlyRenewalWarning: base.showEarlyRenewalWarning,
      migrationAddress: base.migrationAddress,
      previousVaults: base.previousVaults,
    );
    when(
      () => getDetails.execute(details.record.walletId),
    ).thenAnswer((_) async => Ok(details));
    when(
      () => resume.execute(details.record.walletId),
    ).thenAnswer((_) async => const Ok(null));
    final reference = BullVaultTimeReference(
      deviceTime: DateTime.utc(2028),
      chainHeight: 3_100_000,
      medianTimePast:
          DateTime.utc(2027, 12, 31, 23).millisecondsSinceEpoch ~/ 1000,
    );
    when(
      () => prepareTime.execute(isTestnet: details.policy.network.isTestnet),
    ).thenAnswer((_) async => Ok(reference));
    final usecase = LoadBullVaultRenewalUsecase(
      getDetails,
      resume,
      prepareTime,
      _backupStatus(),
    );

    final result = await usecase.execute(details.record.walletId);

    final loaded = (result as Ok).value;
    expect(loaded.details.policy.coldActivationTimestamp, isNotNull);
    expect(loaded.details.policy.recoveryActivationTimestamp, isNotNull);
    expect(loaded.timeReference, reference);
    verify(
      () => prepareTime.execute(isTestnet: details.policy.network.isTestnet),
    ).called(1);
  });

  test('loads incomplete setup without requiring chain access', () async {
    final getDetails = _MockGetDetails();
    final resume = _MockResumeRenewal();
    final prepareTime = _MockPrepareTime();
    final checkBackups = _MockCheckBackups();
    final base = testBullVaultDetails();
    final details = BullVaultDetails(
      record: base.record.copyWith(hardwareSetupComplete: true),
      policy: base.policy,
      timeUntilFirstRecovery: base.timeUntilFirstRecovery,
      showEarlyRenewalWarning: base.showEarlyRenewalWarning,
      migrationAddress: base.migrationAddress,
    );
    when(
      () => getDetails.execute(details.record.walletId),
    ).thenAnswer((_) async => Ok(details));
    when(
      () => resume.execute(details.record.walletId),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => checkBackups.execute(
        details.policy.everydayKey.accountKey.masterFingerprint,
      ),
    ).thenAnswer((_) async => const Ok((physical: false, recoverBull: false)));
    final usecase = LoadBullVaultRenewalUsecase(
      getDetails,
      resume,
      prepareTime,
      checkBackups,
    );

    final result = await usecase.execute(details.record.walletId);

    final loaded = (result as Ok).value;
    expect(loaded.needsInitialSetup, isTrue);
    expect(loaded.timeReference, isNull);
    verifyNever(() => prepareTime.execute(isTestnet: any(named: 'isTestnet')));
  });
}

_MockCheckBackups _backupStatus() {
  final usecase = _MockCheckBackups();
  when(
    () => usecase.execute(any()),
  ).thenAnswer((_) async => const Ok((physical: true, recoverBull: false)));
  return usecase;
}

BullVaultCreateRequest _createRequest() => BullVaultCreateRequest(
  label: 'BullVault',
  protection: BullVaultProtection.standard,
  cold: const BullVaultSignerRequest(
    input: '[deadbeef/48h/0h/0h/2h]xpub',
    device: null,
    genericExternal: true,
  ),
  secondCold: null,
  inheritance: null,
  schedule: BullVaultSchedule.standardWithoutInheritance,
  timeReference: BullVaultTimeReference(
    deviceTime: DateTime.utc(2027),
    chainHeight: 3_000_000,
    medianTimePast: DateTime.utc(2027).millisecondsSinceEpoch ~/ 1000,
  ),
);
