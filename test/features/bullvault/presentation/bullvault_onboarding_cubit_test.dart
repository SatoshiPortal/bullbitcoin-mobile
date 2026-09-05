import 'dart:async';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_key_source.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_onboarding_snapshot.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_initial_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_registration_name_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _MockCreateBullVaultOnboardingUsecase extends Mock
    implements CreateBullVaultOnboardingUsecase {}

class _MockEncodeRecoveryPackageUsecase extends Mock
    implements EncodeBullVaultRecoveryPackageUsecase {}

class _MockLoadBullVaultOnboardingUsecase extends Mock
    implements LoadBullVaultOnboardingUsecase {}

class _MockPrepareBullVaultTimeReferenceUsecase extends Mock
    implements PrepareBullVaultTimeReferenceUsecase {}

class _MockCheckBullVaultMobileBackupsUsecase extends Mock
    implements CheckBullVaultMobileBackupsUsecase {}

class _MockUpdateBullVaultSetupUsecase extends Mock
    implements UpdateBullVaultSetupUsecase {}

class _MockActivateInitialBullVaultUsecase extends Mock
    implements ActivateInitialBullVaultUsecase {}

class _MockUpdateBullVaultRegistrationNameUsecase extends Mock
    implements UpdateBullVaultRegistrationNameUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      BullVaultCreateRequest(
        label: 'BullVault',
        protection: BullVaultProtection.standard,
        cold: const BullVaultSignerRequest(
          input: 'cold-account-key',
          device: null,
          genericExternal: true,
        ),
        secondCold: null,
        inheritance: null,
        schedule: BullVaultSchedule.standardWithoutInheritance,
        timeReference: _timeReference(),
      ),
    );
  });

  test('loads setup for the active mainnet network', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    final cubit = _cubit(load: load);

    await cubit.load();

    expect(cubit.state.network, Network.bitcoinMainnet);
    expect(cubit.state.step, BullVaultOnboardingStep.setupChoice);
    expect(cubit.state.canContinue, isTrue);
    await cubit.next();
    expect(cubit.state.step, BullVaultOnboardingStep.inheritanceChoice);
    cubit.setInheritance(false);
    await cubit.next();
    expect(cubit.state.step, BullVaultOnboardingStep.coldSigner);
    expect(cubit.state.protection, BullVaultProtection.standard);
    expect(cubit.state.includeInheritance, isFalse);
    expect(cubit.state.schedule.coldDelay, 2);
    expect(cubit.state.schedule.recoveryDelay, 3);
    expect(cubit.state.failure, isNull);
    await cubit.close();
  });

  test('keeps advanced choices when the regular flow starts', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    final cubit = _cubit(load: load);
    await cubit.load();

    cubit.setColdYears(6);
    cubit.setRecoveryYears(8);
    cubit.setProtection(BullVaultProtection.extra);
    await cubit.next();
    cubit.setInheritance(false);
    expect(cubit.state.step, BullVaultOnboardingStep.inheritanceChoice);
    expect(cubit.state.protection, BullVaultProtection.extra);
    expect(cubit.state.schedule.coldDelay, 6);
    expect(cubit.state.schedule.recoveryDelay, 8);
    await cubit.close();
  });

  test('uses the selected profile schedule', () async {
    final cubit = _cubit();

    cubit.setProtection(BullVaultProtection.extra);
    cubit.setInheritance(false);

    expect(cubit.state.schedule.coldDelay, 3);
    expect(cubit.state.schedule.recoveryDelay, 5);

    cubit.setInheritance(true);

    expect(cubit.state.schedule.recoveryDelay, 2);
    expect(cubit.state.schedule.inheritanceDelay, 5);
    await cubit.close();
  });

  test('freezes the phone time before opening review', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
    final reference = BullVaultTimeReference(
      deviceTime: DateTime.utc(2027, 1, 15, 12),
      chainHeight: 900_000,
      medianTimePast:
          DateTime.utc(2027, 1, 15, 11).millisecondsSinceEpoch ~/ 1000,
    );
    when(
      () => prepare.execute(isTestnet: false),
    ).thenAnswer((_) async => Ok(reference));
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    final cubit = _cubit(load: load, prepare: prepare);
    await cubit.load();
    cubit.setProtection(BullVaultProtection.standard);
    await cubit.next();
    cubit.setInheritance(false);
    await cubit.next();
    cubit.selectColdDevice(SignerDeviceEntity.ledgerNanoX);
    cubit.setColdInput('account-key');
    await cubit.next();

    expect(cubit.state.step, BullVaultOnboardingStep.review);
    expect(cubit.state.timeReference, same(reference));
    await cubit.close();
  });

  test('creates the selected BullVault and opens recovery setup', () async {
    final create = _MockCreateBullVaultOnboardingUsecase();
    final load = _MockLoadBullVaultOnboardingUsecase();
    final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
    final encode = _MockEncodeRecoveryPackageUsecase();
    final result = _completionResult();
    final reference = _timeReference();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    when(
      () => prepare.execute(isTestnet: false),
    ).thenAnswer((_) async => Ok(reference));
    when(() => create.execute(any())).thenAnswer(
      (_) async => Ok(
        BullVaultOnboardingSnapshot(
          result: result,
          mobileBackupStatus: const Ok((physical: false, recoverBull: false)),
        ),
      ),
    );
    when(() => encode.execute(result.recoveryPackage)).thenReturn('{}');
    final cubit = _cubit(
      create: create,
      load: load,
      prepare: prepare,
      encode: encode,
    );

    await _moveToReview(cubit);
    await cubit.create(walletLabel: 'My BullVault');

    final request =
        verify(() => create.execute(captureAny())).captured.single
            as BullVaultCreateRequest;
    expect(request.label, 'My BullVault');
    expect(request.cold.input, 'cold-account-key');
    expect(request.cold.genericExternal, isTrue);
    expect(request.timeReference, same(reference));
    expect(cubit.state.step, BullVaultOnboardingStep.recoveryPackage);
    expect(cubit.state.result, same(result));
    expect(cubit.state.isCreating, isFalse);
    await cubit.close();
  });

  test('refreshes an expired review before allowing a retry', () async {
    final create = _MockCreateBullVaultOnboardingUsecase();
    final load = _MockLoadBullVaultOnboardingUsecase();
    final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
    final initial = _timeReference();
    final refreshed = BullVaultTimeReference(
      deviceTime: initial.deviceTime.add(const Duration(minutes: 10)),
      chainHeight: initial.chainHeight + 1,
      medianTimePast: initial.medianTimePast + 600,
    );
    var preparationCount = 0;
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    when(() => prepare.execute(isTestnet: false)).thenAnswer(
      (_) async => Ok(preparationCount++ == 0 ? initial : refreshed),
    );
    when(
      () => create.execute(any()),
    ).thenAnswer((_) async => const Err(BullVaultReviewExpiredFailure()));
    final cubit = _cubit(create: create, load: load, prepare: prepare);

    await _moveToReview(cubit);
    await cubit.create(walletLabel: 'BullVault');

    expect(cubit.state.step, BullVaultOnboardingStep.review);
    expect(cubit.state.timeReference, same(refreshed));
    expect(cubit.state.failure, isA<BullVaultReviewExpiredFailure>());
    expect(cubit.state.isCreating, isFalse);
    await cubit.close();
  });

  test('requires passphrase re-entry after creation fails', () async {
    final create = _MockCreateBullVaultOnboardingUsecase();
    final load = _MockLoadBullVaultOnboardingUsecase();
    final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    when(
      () => prepare.execute(isTestnet: false),
    ).thenAnswer((_) async => Ok(_timeReference()));
    when(
      () => create.execute(any()),
    ).thenAnswer((_) async => const Err(BullVaultCreationFailure()));
    final cubit = _cubit(create: create, load: load, prepare: prepare);

    await cubit.load();
    cubit.setMobilePassphraseProtection(enabled: true);
    await cubit.next();
    cubit.setInheritance(false);
    await cubit.next();
    cubit.useGenericColdSigner();
    cubit.setColdInput('cold-account-key');
    await cubit.next();
    expect(cubit.state.step, BullVaultOnboardingStep.mobilePassphrase);

    cubit.setMobilePassphrase('vault passphrase');
    cubit.confirmMobilePassphraseBackup(true);
    await cubit.next();
    await cubit.create(walletLabel: 'BullVault');

    final request =
        verify(() => create.execute(captureAny())).captured.single
            as BullVaultCreateRequest;
    expect(request.mobilePassphrase, 'vault passphrase');
    expect(cubit.state.step, BullVaultOnboardingStep.mobilePassphrase);
    expect(cubit.state.mobilePassphraseReady, isFalse);
    expect(cubit.state.mobilePassphraseBackedUp, isFalse);
    await cubit.close();
  });

  test('continues after a device key and returns to its setup step', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    when(
      () => prepare.execute(isTestnet: false),
    ).thenAnswer((_) async => Ok(_timeReference()));
    final cubit = _cubit(load: load, prepare: prepare);

    await cubit.load();
    await cubit.next();
    cubit.setInheritance(false);
    await cubit.next();
    await cubit.next();
    cubit.selectColdDevice(SignerDeviceEntity.ledgerNanoX);
    await cubit.acceptColdKeyAndContinue('cold-account-key');

    expect(cubit.state.step, BullVaultOnboardingStep.review);
    expect(cubit.state.coldInput, 'cold-account-key');
    cubit.back();
    expect(cubit.state.step, BullVaultOnboardingStep.coldSigner);
    expect(cubit.state.timeReference, isNull);
    cubit.back();
    expect(cubit.state.step, BullVaultOnboardingStep.inheritanceChoice);
    await cubit.close();
  });

  test('does not reopen review after leaving while it is prepared', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
    final review =
        Completer<Result<BullVaultTimeReference, BullVaultFailure>>();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    when(
      () => prepare.execute(isTestnet: false),
    ).thenAnswer((_) => review.future);
    final cubit = _cubit(load: load, prepare: prepare);

    await cubit.load();
    await cubit.next();
    cubit.setInheritance(false);
    await cubit.next();
    cubit.selectColdDevice(SignerDeviceEntity.ledgerNanoX);
    final acquisition = cubit.acceptColdKeyAndContinue('cold-account-key');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.step, BullVaultOnboardingStep.coldSigner);
    expect(cubit.state.isPreparingReview, isTrue);

    cubit.back();
    expect(cubit.state.step, BullVaultOnboardingStep.inheritanceChoice);
    expect(cubit.state.isPreparingReview, isFalse);

    review.complete(Ok(_timeReference()));
    await acquisition;
    expect(cubit.state.step, BullVaultOnboardingStep.inheritanceChoice);
    expect(cubit.state.timeReference, isNull);
    await cubit.close();
  });

  test('preserves signer-step order for extra protection', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    when(
      () => prepare.execute(isTestnet: false),
    ).thenAnswer((_) async => Ok(_timeReference()));
    final cubit = _cubit(load: load, prepare: prepare);

    await cubit.load();
    cubit.setProtection(BullVaultProtection.extra);
    await cubit.next();
    cubit.setInheritance(true);
    await cubit.next();

    cubit.selectColdDevice(SignerDeviceEntity.ledgerNanoX);
    await cubit.acceptColdKeyAndContinue('first-cold-account-key');
    expect(cubit.state.step, BullVaultOnboardingStep.secondColdSigner);
    cubit.back();
    expect(cubit.state.step, BullVaultOnboardingStep.coldSigner);

    await cubit.acceptColdKeyAndContinue('first-cold-account-key');
    cubit.selectSecondColdDevice(SignerDeviceEntity.bitbox02);
    await cubit.acceptSecondColdKeyAndContinue('second-cold-account-key');
    expect(cubit.state.step, BullVaultOnboardingStep.inheritance);
    cubit.back();
    expect(cubit.state.step, BullVaultOnboardingStep.secondColdSigner);

    await cubit.acceptSecondColdKeyAndContinue('second-cold-account-key');
    cubit.selectInheritanceDevice(SignerDeviceEntity.krux);
    await cubit.acceptInheritanceKeyAndContinue('inheritance-account-key');
    expect(cubit.state.step, BullVaultOnboardingStep.review);
    cubit.back();
    expect(cubit.state.step, BullVaultOnboardingStep.inheritance);
    await cubit.close();
  });

  test('adds the inheritance key step only when selected', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    final cubit = _cubit(load: load);
    await cubit.load();

    cubit.setProtection(BullVaultProtection.standard);
    await cubit.next();
    cubit.setInheritance(true);
    await cubit.next();
    expect(cubit.state.step, BullVaultOnboardingStep.coldSigner);
    expect(cubit.state.includeInheritance, isTrue);
    cubit.selectColdDevice(SignerDeviceEntity.ledgerNanoX);
    cubit.setColdInput('cold-account-key');
    await cubit.next();

    expect(cubit.state.step, BullVaultOnboardingStep.inheritance);
    expect(cubit.state.canContinue, isFalse);
    cubit.setInheritanceSource(BullVaultInheritanceKeySource.publicAccountKey);
    cubit.setInheritanceInput('inheritance-account-key');
    expect(cubit.state.inheritanceDevice, isNull);
    expect(cubit.state.genericInheritanceSigner, isTrue);
    expect(cubit.state.canContinue, isTrue);
    await cubit.close();
  });

  test('collects a second cold key only for extra protection', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    final cubit = _cubit(load: load);
    await cubit.load();

    cubit.setProtection(BullVaultProtection.extra);
    await cubit.next();
    cubit.setInheritance(false);
    await cubit.next();
    cubit.selectColdDevice(SignerDeviceEntity.ledgerNanoX);
    cubit.setColdInput('first-cold-account-key');
    await cubit.next();

    expect(cubit.state.step, BullVaultOnboardingStep.secondColdSigner);
    expect(cubit.state.canContinue, isFalse);
    cubit.selectSecondColdDevice(SignerDeviceEntity.bitbox02);
    cubit.setSecondColdInput('second-cold-account-key');
    expect(cubit.state.canContinue, isTrue);
    await cubit.close();
  });

  for (final mobile in [false, true]) {
    test('skips only applicable completion tasks (mobile: $mobile)', () async {
      final load = _MockLoadBullVaultOnboardingUsecase();
      final update = _MockUpdateBullVaultSetupUsecase();
      final encode = _MockEncodeRecoveryPackageUsecase();
      final result = _completionResult(usesBullMobile: mobile);
      when(load.execute).thenAnswer(
        (_) async => Ok(
          BullVaultOnboardingLoad(
            network: Network.bitcoinMainnet,
            snapshot: BullVaultOnboardingSnapshot(
              result: result,
              mobileBackupStatus: const Ok((
                physical: false,
                recoverBull: false,
              )),
            ),
          ),
        ),
      );
      when(
        () => update.execute(
          walletId: result.wallet.id,
          recoveryPackageConfirmed: true,
        ),
      ).thenAnswer((_) async => Ok(result.record));
      when(() => encode.execute(result.recoveryPackage)).thenReturn('{}');
      final cubit = _cubit(load: load, update: update, encode: encode);

      await cubit.load();
      expect(cubit.state.step, BullVaultOnboardingStep.recoveryPackage);

      cubit.markRecoveryPackageExported();
      await cubit.confirmRecoveryPackage();
      await cubit.next();
      expect(cubit.state.step, BullVaultOnboardingStep.hardwareSetup);

      await cubit.deferHardwareSetup();
      if (mobile) {
        expect(cubit.state.step, BullVaultOnboardingStep.mobileBackup);
        await cubit.deferMobileBackup();
      }
      expect(cubit.state.step, BullVaultOnboardingStep.complete);
      expect(cubit.state.canOpenWallet, isTrue);
      await cubit.close();
    });
  }

  test('does not infer setup deferral for a newly restored vault', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    final encode = _MockEncodeRecoveryPackageUsecase();
    final initial = _completionResult();
    final record = initial.record.copyWith(
      status: BullVaultLifecycleStatus.active,
      recoveryPackageConfirmed: true,
    );
    final result = BullVaultCreateResult(
      wallet: initial.wallet,
      record: record,
    );
    when(() => load.execute(walletId: result.wallet.id)).thenAnswer(
      (_) async => Ok(
        BullVaultOnboardingLoad(
          network: Network.bitcoinMainnet,
          snapshot: BullVaultOnboardingSnapshot(
            result: result,
            mobileBackupStatus: const Ok((physical: false, recoverBull: false)),
          ),
        ),
      ),
    );
    when(() => encode.execute(result.recoveryPackage)).thenReturn('{}');
    final cubit = _cubit(load: load, encode: encode);

    await cubit.load(walletId: result.wallet.id);

    expect(cubit.state.step, BullVaultOnboardingStep.hardwareSetup);
    expect(cubit.state.hardwareSetupDeferred, isFalse);
    expect(cubit.state.mobileBackupDeferred, isFalse);
    expect(cubit.state.canContinue, isFalse);
    await cubit.close();
  });

  test('persists deferred setup for an active restored vault', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    final update = _MockUpdateBullVaultSetupUsecase();
    final encode = _MockEncodeRecoveryPackageUsecase();
    final initial = _completionResult();
    final record = initial.record.copyWith(
      status: BullVaultLifecycleStatus.active,
      recoveryPackageConfirmed: true,
    );
    final result = BullVaultCreateResult(
      wallet: initial.wallet,
      record: record,
    );
    when(() => load.execute(walletId: result.wallet.id)).thenAnswer(
      (_) async => Ok(
        BullVaultOnboardingLoad(
          network: Network.bitcoinMainnet,
          snapshot: BullVaultOnboardingSnapshot(
            result: result,
            mobileBackupStatus: const Ok((physical: false, recoverBull: false)),
          ),
        ),
      ),
    );
    when(() => encode.execute(result.recoveryPackage)).thenReturn('{}');
    when(
      () => update.execute(
        walletId: result.wallet.id,
        hardwareSetupDeferred: true,
      ),
    ).thenAnswer((_) async => Ok(record.copyWith(hardwareSetupDeferred: true)));
    when(
      () => update.execute(
        walletId: result.wallet.id,
        mobileBackupDeferred: true,
      ),
    ).thenAnswer((_) async => Ok(record.copyWith(mobileBackupDeferred: true)));
    final cubit = _cubit(load: load, update: update, encode: encode);

    await cubit.load(walletId: result.wallet.id);
    await cubit.deferHardwareSetup();
    await cubit.deferMobileBackup();

    expect(cubit.state.step, BullVaultOnboardingStep.complete);
    expect(cubit.state.hardwareSetupDeferred, isTrue);
    expect(cubit.state.mobileBackupDeferred, isTrue);
    verify(
      () => update.execute(
        walletId: result.wallet.id,
        hardwareSetupDeferred: true,
      ),
    ).called(1);
    verify(
      () => update.execute(
        walletId: result.wallet.id,
        mobileBackupDeferred: true,
      ),
    ).called(1);
    await cubit.close();
  });

  test('keeps the completion step locked while activation succeeds', () async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    final activate = _MockActivateInitialBullVaultUsecase();
    final encode = _MockEncodeRecoveryPackageUsecase();
    final result = _readyPendingResult();
    final activation = Completer<Result<void, BullVaultFailure>>();
    when(load.execute).thenAnswer(
      (_) async => Ok(
        BullVaultOnboardingLoad(
          network: Network.bitcoinMainnet,
          snapshot: BullVaultOnboardingSnapshot(
            result: result,
            mobileBackupStatus: const Ok((physical: true, recoverBull: false)),
          ),
        ),
      ),
    );
    when(() => encode.execute(result.recoveryPackage)).thenReturn('{}');
    when(
      () => activate.execute(
        walletId: result.wallet.id,
        hardwareSetupDeferred: false,
        hasMobileBackup: true,
        mobileBackupDeferred: false,
      ),
    ).thenAnswer((_) => activation.future);
    final cubit = _cubit(load: load, activate: activate, encode: encode);
    await cubit.load();

    final outcome = cubit.activate();
    expect(cubit.state.step, BullVaultOnboardingStep.complete);
    expect(cubit.state.isActivating, isTrue);
    cubit.back();
    expect(cubit.state.step, BullVaultOnboardingStep.complete);
    activation.complete(const Ok(null));

    expect(await outcome, isTrue);
    await cubit.close();
  });

  test(
    'keeps the vault open action available after activation fails',
    () async {
      final load = _MockLoadBullVaultOnboardingUsecase();
      final activate = _MockActivateInitialBullVaultUsecase();
      final encode = _MockEncodeRecoveryPackageUsecase();
      final result = _readyPendingResult();
      when(load.execute).thenAnswer(
        (_) async => Ok(
          BullVaultOnboardingLoad(
            network: Network.bitcoinMainnet,
            snapshot: BullVaultOnboardingSnapshot(
              result: result,
              mobileBackupStatus: const Ok((
                physical: true,
                recoverBull: false,
              )),
            ),
          ),
        ),
      );
      when(() => encode.execute(result.recoveryPackage)).thenReturn('{}');
      when(
        () => activate.execute(
          walletId: result.wallet.id,
          hardwareSetupDeferred: false,
          hasMobileBackup: true,
          mobileBackupDeferred: false,
        ),
      ).thenAnswer((_) async => const Err(BullVaultCreationFailure()));
      final cubit = _cubit(load: load, activate: activate, encode: encode);
      await cubit.load();

      expect(await cubit.activate(), isFalse);

      expect(cubit.state.step, BullVaultOnboardingStep.complete);
      expect(cubit.state.isActivating, isFalse);
      expect(cubit.state.canOpenWallet, isTrue);
      expect(cubit.state.failure, isA<BullVaultCreationFailure>());
      await cubit.close();
    },
  );
}

BullVaultOnboardingCubit _cubit({
  _MockCreateBullVaultOnboardingUsecase? create,
  _MockLoadBullVaultOnboardingUsecase? load,
  _MockPrepareBullVaultTimeReferenceUsecase? prepare,
  _MockUpdateBullVaultSetupUsecase? update,
  _MockActivateInitialBullVaultUsecase? activate,
  _MockEncodeRecoveryPackageUsecase? encode,
}) => BullVaultOnboardingCubit(
  create ?? _MockCreateBullVaultOnboardingUsecase(),
  prepare ?? _MockPrepareBullVaultTimeReferenceUsecase(),
  load ?? _MockLoadBullVaultOnboardingUsecase(),
  _MockCheckBullVaultMobileBackupsUsecase(),
  update ?? _MockUpdateBullVaultSetupUsecase(),
  activate ?? _MockActivateInitialBullVaultUsecase(),
  encode ?? _MockEncodeRecoveryPackageUsecase(),
  _MockUpdateBullVaultRegistrationNameUsecase(),
);

Future<void> _moveToReview(BullVaultOnboardingCubit cubit) async {
  await cubit.load();
  await cubit.next();
  cubit.setInheritance(false);
  await cubit.next();
  cubit.useGenericColdSigner();
  cubit.setColdInput('cold-account-key');
  await cubit.next();
}

BullVaultTimeReference _timeReference() => BullVaultTimeReference(
  deviceTime: DateTime.utc(2027, 1, 15, 12),
  chainHeight: 900_000,
  medianTimePast: DateTime.utc(2027, 1, 15, 11).millisecondsSinceEpoch ~/ 1000,
);

BullVaultCreateResult _completionResult({bool usesBullMobile = true}) {
  final result = testBullVaultCreateResult(usesBullMobile: usesBullMobile);
  final everyday = result.policy.everydayKey.accountKey;
  final cold = result.policy.coldKey.accountKey;
  return BullVaultCreateResult(
    wallet: result.wallet.copyWith(
      signers: [
        WalletSigner(
          id: 'everyday',
          signer: usesBullMobile ? SignerEntity.local : SignerEntity.remote,
          signerDevice: null,
          descriptorKeys: [everyday.copyWith(signerId: 'everyday')],
        ),
        WalletSigner(
          id: 'cold',
          signer: SignerEntity.remote,
          signerDevice: null,
          descriptorKeys: [cold.copyWith(signerId: 'cold')],
        ),
      ],
    ),
    record: result.record,
  );
}

BullVaultCreateResult _readyPendingResult() {
  final result = _completionResult();
  final record = result.record.copyWith(
    completedHardwareSignerIds: const {'cold'},
    recoveryPackageConfirmed: true,
  );
  return BullVaultCreateResult(wallet: result.wallet, record: record);
}
