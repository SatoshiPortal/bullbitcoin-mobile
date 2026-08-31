import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bip48_account_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_wallet_hidden_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_initial_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/cancel_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/reconcile_bullvault_visibility_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault_test_fixture.dart';

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockSetWalletHiddenUsecase extends Mock
    implements SetWalletHiddenUsecase {}

class _MockResumeBullVaultRenewalUsecase extends Mock
    implements ResumeBullVaultRenewalUsecase {}

class _MockResumeBullVaultOnboardingUsecase extends Mock
    implements ResumeBullVaultOnboardingUsecase {}

class _MockReserveBip48AccountUsecase extends Mock
    implements ReserveBip48AccountUsecase {}

final class _RenewalRepository implements BullVaultRepository {
  final Map<String, BullVaultRecord> records;
  final bool failActivation;
  final int? failSaveAt;
  BullVaultRecord? activatedReplacement;
  var _saveCount = 0;

  _RenewalRepository({
    required this.records,
    this.failActivation = false,
    this.failSaveAt,
  });

  @override
  Result<BullVaultRecoveryPackage, BullVaultFailure> decodeRecoveryPackage(
    String source,
  ) => throw UnimplementedError();

  @override
  String encodeRecoveryPackage(BullVaultRecoveryPackage recoveryPackage) =>
      throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> activateRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord replacement,
  }) async {
    activatedReplacement = replacement;
    return failActivation
        ? const Err(BullVaultRenewalFailure())
        : const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> cancelRenewal({
    required String previousWalletId,
    required String replacementWalletId,
  }) async {
    final previous = records[previousWalletId];
    final replacement = records[replacementWalletId];
    if (previous?.status != BullVaultLifecycleStatus.active ||
        replacement?.status != BullVaultLifecycleStatus.pending ||
        replacement?.previousVaultId != previousWalletId) {
      return const Err(BullVaultRenewalFailure());
    }
    records[replacementWalletId] = replacement!.copyWith(
      status: BullVaultLifecycleStatus.cancelled,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> linkRestoredRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord successor,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String walletId,
  ) async => Ok(records[walletId]);

  @override
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getLineage(
    String lineageId,
  ) async => Ok(
    records.values.where((record) => record.lineageId == lineageId).toList(),
  );

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getIncompleteInitial(
    Network network,
  ) => throw UnimplementedError();

  @override
  Future<Result<int, BullVaultFailure>> reserveNextGeneration(
    BullVaultRecord current,
  ) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> releaseGeneration({
    required String lineageId,
    required int generation,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record) async {
    _saveCount++;
    if (_saveCount == failSaveAt) {
      return const Err(BullVaultCreationFailure());
    }
    records[record.walletId] = record;
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> delete(String walletId) async {
    records.remove(walletId);
    return const Ok(null);
  }
}

void main() {
  test('persists completed device and recovery-package setup', () async {
    final replacement = _replacement();
    final repository = _RenewalRepository(
      records: {replacement.walletId: replacement},
    );
    final getWallet = _MockGetWalletUsecase();
    when(
      () => getWallet.execute(replacement.walletId),
    ).thenAnswer((_) async => _replacementWallet());
    final usecase = UpdateBullVaultSetupUsecase(repository, getWallet);

    final signerResult = await usecase.execute(
      walletId: replacement.walletId,
      completedHardwareSignerId: 'cold',
    );
    final recoveryResult = await usecase.execute(
      walletId: replacement.walletId,
      recoveryPackageConfirmed: true,
    );

    expect(
      (signerResult as Ok<BullVaultRecord, BullVaultFailure>)
          .value
          .completedHardwareSignerIds,
      {'cold'},
    );
    expect(
      (recoveryResult as Ok<BullVaultRecord, BullVaultFailure>)
          .value
          .recoveryPackageConfirmed,
      isTrue,
    );
  });

  test(
    'completes deferred hardware setup for an active initial vault',
    () async {
      final active = _initial().copyWith(
        status: BullVaultLifecycleStatus.active,
      );
      final repository = _RenewalRepository(records: {active.walletId: active});
      final getWallet = _MockGetWalletUsecase();
      when(
        () => getWallet.execute(active.walletId),
      ).thenAnswer((_) async => _initialWallet());
      final usecase = UpdateBullVaultSetupUsecase(repository, getWallet);

      final result = await usecase.execute(
        walletId: active.walletId,
        completedHardwareSignerId: 'cold',
      );

      final updated = (result as Ok<BullVaultRecord, BullVaultFailure>).value;
      expect(updated.completedHardwareSignerIds, {'cold'});
      expect(updated.hardwareSetupComplete, isTrue);
    },
  );

  test('completes setup for an active restored renewal', () async {
    final active = _replacement().copyWith(
      status: BullVaultLifecycleStatus.active,
      hardwareSetupDeferred: true,
    );
    final repository = _RenewalRepository(records: {active.walletId: active});
    final getWallet = _MockGetWalletUsecase();
    when(
      () => getWallet.execute(active.walletId),
    ).thenAnswer((_) async => _replacementWallet());
    final usecase = UpdateBullVaultSetupUsecase(repository, getWallet);

    final hardware = await usecase.execute(
      walletId: active.walletId,
      completedHardwareSignerId: 'cold',
    );
    final recovery = await usecase.execute(
      walletId: active.walletId,
      recoveryPackageConfirmed: true,
    );

    expect(hardware, isA<Ok<BullVaultRecord, BullVaultFailure>>());
    final updated = (recovery as Ok<BullVaultRecord, BullVaultFailure>).value;
    expect(updated.vaultGeneration, 1);
    expect(updated.hardwareSetupComplete, isTrue);
    expect(updated.hardwareSetupDeferred, isFalse);
    expect(updated.recoveryPackageConfirmed, isTrue);
  });

  test('persists explicit setup deferrals for an active vault', () async {
    final active = _replacement().copyWith(
      status: BullVaultLifecycleStatus.active,
    );
    final repository = _RenewalRepository(records: {active.walletId: active});
    final usecase = UpdateBullVaultSetupUsecase(
      repository,
      _MockGetWalletUsecase(),
    );

    final result = await usecase.execute(
      walletId: active.walletId,
      hardwareSetupDeferred: true,
      mobileBackupDeferred: true,
    );

    final updated = (result as Ok<BullVaultRecord, BullVaultFailure>).value;
    expect(updated.hardwareSetupDeferred, isTrue);
    expect(updated.mobileBackupDeferred, isTrue);
    expect(repository.records[active.walletId], same(updated));
  });

  test(
    'cancels an empty pending replacement without changing its predecessor',
    () async {
      final previous = _previous();
      final replacement = _replacement();
      final repository = _RenewalRepository(
        records: {
          previous.walletId: previous,
          replacement.walletId: replacement,
        },
      );
      final getWallet = _MockGetWalletUsecase();
      when(
        () => getWallet.execute(replacement.walletId, sync: true),
      ).thenAnswer((_) async => _replacementWallet());
      final usecase = CancelBullVaultRenewalUsecase(repository, getWallet);

      final result = await usecase.execute(
        previousWalletId: previous.walletId,
        replacementWalletId: replacement.walletId,
      );

      expect(result, isA<Ok<void, BullVaultFailure>>());
      expect(repository.records[previous.walletId], same(previous));
      expect(
        repository.records[replacement.walletId]!.status,
        BullVaultLifecycleStatus.cancelled,
      );
    },
  );

  test('keeps a funded replacement pending', () async {
    final previous = _previous();
    final replacement = _replacement();
    final repository = _RenewalRepository(
      records: {previous.walletId: previous, replacement.walletId: replacement},
    );
    final getWallet = _MockGetWalletUsecase();
    when(
      () => getWallet.execute(replacement.walletId, sync: true),
    ).thenAnswer((_) async => _replacementWallet(balanceSat: BigInt.one));
    final usecase = CancelBullVaultRenewalUsecase(repository, getWallet);

    final result = await usecase.execute(
      previousWalletId: previous.walletId,
      replacementWalletId: replacement.walletId,
    );

    expect(switch (result) {
      Err(:final failure) => failure,
      Ok() => null,
    }, isA<BullVaultRenewalHasFundsFailure>());
    expect(
      repository.records[replacement.walletId]!.status,
      BullVaultLifecycleStatus.pending,
    );
  });

  test('treats an already activated renewal as success', () async {
    final previous = _previous().copyWith(
      successorWalletId: 'wallet-1',
      status: BullVaultLifecycleStatus.migrating,
    );
    final replacement = _replacement(
      completedHardwareSignerIds: const {'cold'},
      recoveryPackageConfirmed: true,
    ).copyWith(status: BullVaultLifecycleStatus.active);
    final repository = _RenewalRepository(
      records: {previous.walletId: previous, replacement.walletId: replacement},
    );
    final getWallet = _MockGetWalletUsecase();
    final setHidden = _MockSetWalletHiddenUsecase();
    when(
      () => setHidden.execute(
        walletId: any(named: 'walletId'),
        isHidden: any(named: 'isHidden'),
      ),
    ).thenAnswer((_) async {});
    final usecase = ActivateBullVaultRenewalUsecase(
      repository,
      getWallet,
      setHidden,
    );

    final result = await usecase.execute(
      previousWalletId: previous.walletId,
      replacementWalletId: replacement.walletId,
    );

    expect(result, isA<Ok<void, BullVaultFailure>>());
    verifyInOrder([
      () => setHidden.execute(walletId: replacement.walletId, isHidden: false),
      () => setHidden.execute(walletId: previous.walletId, isHidden: true),
    ]);
  });

  test('leaves reconciled renewal visibility unchanged', () async {
    final previous = _previous().copyWith(
      successorWalletId: 'wallet-1',
      status: BullVaultLifecycleStatus.migrating,
    );
    final replacement = _replacement(
      recoveryPackageConfirmed: true,
    ).copyWith(status: BullVaultLifecycleStatus.active);
    final repository = _RenewalRepository(
      records: {previous.walletId: previous, replacement.walletId: replacement},
    );
    final getWallet = _MockGetWalletUsecase();
    final setHidden = _MockSetWalletHiddenUsecase();
    when(
      () => getWallet.execute(replacement.walletId),
    ).thenAnswer((_) async => _replacementWallet());
    when(
      () => getWallet.execute(previous.walletId),
    ).thenAnswer((_) async => _previousWallet(isHidden: true));
    final usecase = ResumeBullVaultRenewalUsecase(
      repository,
      getWallet,
      setHidden,
    );

    final result = await usecase.execute(replacement.walletId);

    expect(result, isA<Ok>());
    verifyNever(
      () => setHidden.execute(
        walletId: any(named: 'walletId'),
        isHidden: any(named: 'isHidden'),
      ),
    );
  });

  test('activates only after persisted setup is complete', () async {
    final previous = _previous();
    final replacement = _replacement(
      completedHardwareSignerIds: const {'cold'},
      recoveryPackageConfirmed: true,
    );
    final repository = _RenewalRepository(
      records: {previous.walletId: previous, replacement.walletId: replacement},
    );
    final getWallet = _MockGetWalletUsecase();
    final setHidden = _MockSetWalletHiddenUsecase();
    when(
      () => getWallet.execute(replacement.walletId),
    ).thenAnswer((_) async => _replacementWallet());
    when(
      () => setHidden.execute(
        walletId: any(named: 'walletId'),
        isHidden: any(named: 'isHidden'),
      ),
    ).thenAnswer((_) async {});
    final usecase = ActivateBullVaultRenewalUsecase(
      repository,
      getWallet,
      setHidden,
    );

    final result = await usecase.execute(
      previousWalletId: previous.walletId,
      replacementWalletId: replacement.walletId,
    );

    expect(result, isA<Ok<void, BullVaultFailure>>());
    expect(repository.activatedReplacement!.hardwareSetupComplete, isTrue);
    verifyInOrder([
      () => setHidden.execute(walletId: replacement.walletId, isHidden: false),
      () => setHidden.execute(walletId: previous.walletId, isHidden: true),
    ]);
  });

  test('restores wallet visibility when activation fails', () async {
    final previous = _previous();
    final replacement = _replacement(
      completedHardwareSignerIds: const {'cold'},
      recoveryPackageConfirmed: true,
    );
    final repository = _RenewalRepository(
      records: {previous.walletId: previous, replacement.walletId: replacement},
      failActivation: true,
    );
    final getWallet = _MockGetWalletUsecase();
    final setHidden = _MockSetWalletHiddenUsecase();
    when(
      () => getWallet.execute(replacement.walletId),
    ).thenAnswer((_) async => _replacementWallet());
    when(
      () => setHidden.execute(
        walletId: any(named: 'walletId'),
        isHidden: any(named: 'isHidden'),
      ),
    ).thenAnswer((_) async {});
    final usecase = ActivateBullVaultRenewalUsecase(
      repository,
      getWallet,
      setHidden,
    );

    final result = await usecase.execute(
      previousWalletId: previous.walletId,
      replacementWalletId: replacement.walletId,
    );

    expect(result, isA<Err<void, BullVaultFailure>>());
    verifyInOrder([
      () => setHidden.execute(walletId: replacement.walletId, isHidden: false),
      () => setHidden.execute(walletId: previous.walletId, isHidden: true),
      () => setHidden.execute(walletId: previous.walletId, isHidden: false),
      () => setHidden.execute(walletId: replacement.walletId, isHidden: true),
    ]);
  });

  test('restores replacement visibility when renewal resume fails', () async {
    final previous = _previous();
    final replacement = _replacement().copyWith(
      status: BullVaultLifecycleStatus.activating,
    );
    final repository = _RenewalRepository(
      records: {previous.walletId: previous, replacement.walletId: replacement},
    );
    final getWallet = _MockGetWalletUsecase();
    final setHidden = _MockSetWalletHiddenUsecase();
    final wallet = Wallet(
      origin: replacement.walletId,
      network: Network.bitcoinMainnet,
      signers: const [],
      scriptType: null,
      publicDescriptor: replacement.recoveryPackage.policy.descriptor,
      balanceSat: BigInt.zero,
      isHidden: true,
    );
    when(
      () => getWallet.execute(replacement.walletId),
    ).thenAnswer((_) async => wallet);
    when(
      () => getWallet.execute(previous.walletId),
    ).thenAnswer((_) async => _previousWallet());
    when(
      () => setHidden.execute(walletId: replacement.walletId, isHidden: false),
    ).thenAnswer((_) async {});
    when(
      () => setHidden.execute(walletId: previous.walletId, isHidden: true),
    ).thenThrow(Exception('storage unavailable'));
    when(
      () => setHidden.execute(walletId: replacement.walletId, isHidden: true),
    ).thenAnswer((_) async {});
    final usecase = ResumeBullVaultRenewalUsecase(
      repository,
      getWallet,
      setHidden,
    );

    final result = await usecase.execute(replacement.walletId);

    expect(result, isA<Err>());
    verifyInOrder([
      () => setHidden.execute(walletId: replacement.walletId, isHidden: false),
      () => setHidden.execute(walletId: previous.walletId, isHidden: true),
      () => setHidden.execute(walletId: replacement.walletId, isHidden: true),
    ]);
  });

  test('validates a replacement before changing wallet visibility', () async {
    final previous = _previous();
    final replacement = _replacement().copyWith(
      status: BullVaultLifecycleStatus.activating,
    );
    final repository = _RenewalRepository(
      records: {previous.walletId: previous, replacement.walletId: replacement},
    );
    final getWallet = _MockGetWalletUsecase();
    final setHidden = _MockSetWalletHiddenUsecase();
    when(() => getWallet.execute(replacement.walletId)).thenAnswer(
      (_) async =>
          _replacementWallet().copyWith(publicDescriptor: 'unexpected'),
    );
    final usecase = ResumeBullVaultRenewalUsecase(
      repository,
      getWallet,
      setHidden,
    );

    final result = await usecase.execute(previous.walletId);

    expect(result, isA<Err>());
    verifyNever(
      () => setHidden.execute(
        walletId: any(named: 'walletId'),
        isHidden: any(named: 'isHidden'),
      ),
    );
  });

  test('continues startup reconciliation after a wallet failure', () async {
    final initial = _initial().copyWith(
      status: BullVaultLifecycleStatus.activating,
    );
    final replacement = _replacement();
    final repository = _RenewalRepository(
      records: {initial.walletId: initial, replacement.walletId: replacement},
    );
    final getWallets = _MockGetWalletsUsecase();
    final resumeOnboarding = _MockResumeBullVaultOnboardingUsecase();
    final resumeRenewal = _MockResumeBullVaultRenewalUsecase();
    final initialWallet = _initialWallet();
    final replacementWallet = _replacementWallet().copyWith(isHidden: true);
    when(
      () => getWallets.execute(includeHidden: true),
    ).thenAnswer((_) async => [initialWallet, replacementWallet]);
    when(
      () => resumeOnboarding.execute(
        initialWallet.network,
        walletId: initialWallet.id,
      ),
    ).thenAnswer((_) async => const Err(BullVaultCreationFailure()));
    when(
      () => resumeRenewal.execute(replacementWallet.id),
    ).thenAnswer((_) async => const Ok(null));
    final usecase = ReconcileBullVaultVisibilityUsecase(
      getWallets,
      repository,
      resumeOnboarding,
      resumeRenewal,
    );

    final result = await usecase.execute();

    expect(result, isA<Err<void, BullVaultFailure>>());
    verify(() => getWallets.execute(includeHidden: true)).called(1);
    verify(
      () => resumeOnboarding.execute(
        initialWallet.network,
        walletId: initialWallet.id,
      ),
    ).called(1);
    verify(() => resumeRenewal.execute(replacementWallet.id)).called(1);
  });

  test('publishes an active wallet when no renewal is pending', () async {
    final active = _initial().copyWith(status: BullVaultLifecycleStatus.active);
    final repository = _RenewalRepository(records: {active.walletId: active});
    final getWallet = _MockGetWalletUsecase();
    final setHidden = _MockSetWalletHiddenUsecase();
    when(
      () => getWallet.execute(active.walletId),
    ).thenAnswer((_) async => _initialWallet());
    when(
      () => setHidden.execute(walletId: active.walletId, isHidden: false),
    ).thenAnswer((_) async {});
    final usecase = ResumeBullVaultRenewalUsecase(
      repository,
      getWallet,
      setHidden,
    );

    final result = await usecase.execute(active.walletId);

    expect(result, isA<Ok>());
    verify(
      () => setHidden.execute(walletId: active.walletId, isHidden: false),
    ).called(1);
  });

  test(
    'keeps an initial vault hidden until mandatory setup is persisted',
    () async {
      final initial = _initial().copyWith(recoveryPackageConfirmed: true);
      final repository = _RenewalRepository(
        records: {initial.walletId: initial},
      );
      final getWallet = _MockGetWalletUsecase();
      final setHidden = _MockSetWalletHiddenUsecase();
      when(
        () => getWallet.execute(initial.walletId),
      ).thenAnswer((_) async => _initialWallet());
      when(
        () => setHidden.execute(
          walletId: any(named: 'walletId'),
          isHidden: any(named: 'isHidden'),
        ),
      ).thenAnswer((_) async {});
      final usecase = ActivateInitialBullVaultUsecase(
        repository,
        getWallet,
        setHidden,
      );

      final beforeHardwareSetup = await usecase.execute(
        walletId: initial.walletId,
        hardwareSetupDeferred: false,
        hasMobileBackup: false,
        mobileBackupDeferred: true,
      );
      expect(beforeHardwareSetup, isA<Err<void, BullVaultFailure>>());
      final beforeMobileBackup = await usecase.execute(
        walletId: initial.walletId,
        hardwareSetupDeferred: true,
        hasMobileBackup: false,
        mobileBackupDeferred: false,
      );
      expect(beforeMobileBackup, isA<Err<void, BullVaultFailure>>());
      verifyNever(
        () => setHidden.execute(
          walletId: any(named: 'walletId'),
          isHidden: any(named: 'isHidden'),
        ),
      );

      repository.records[initial.walletId] = initial.copyWith(
        completedHardwareSignerIds: const {'cold'},
      );
      final activated = await usecase.execute(
        walletId: initial.walletId,
        hardwareSetupDeferred: false,
        hasMobileBackup: false,
        mobileBackupDeferred: true,
      );

      expect(activated, isA<Ok<void, BullVaultFailure>>());
      expect(
        repository.records[initial.walletId]!.status,
        BullVaultLifecycleStatus.active,
      );
      expect(
        repository.records[initial.walletId]!.hardwareSetupDeferred,
        isFalse,
      );
      expect(
        repository.records[initial.walletId]!.mobileBackupDeferred,
        isTrue,
      );
      verify(
        () => setHidden.execute(walletId: initial.walletId, isHidden: false),
      ).called(1);
    },
  );

  test(
    'serializes duplicate initial activation and treats active as success',
    () async {
      final initial = _initial().copyWith(
        recoveryPackageConfirmed: true,
        completedHardwareSignerIds: const {'cold'},
      );
      final repository = _RenewalRepository(
        records: {initial.walletId: initial},
      );
      final getWallet = _MockGetWalletUsecase();
      final setHidden = _MockSetWalletHiddenUsecase();
      when(
        () => getWallet.execute(initial.walletId),
      ).thenAnswer((_) async => _initialWallet());
      when(
        () => setHidden.execute(walletId: initial.walletId, isHidden: false),
      ).thenAnswer(
        (_) async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      final first = ActivateInitialBullVaultUsecase(
        repository,
        getWallet,
        setHidden,
      );
      final second = ActivateInitialBullVaultUsecase(
        repository,
        getWallet,
        setHidden,
      );

      final results = await Future.wait([
        first.execute(
          walletId: initial.walletId,
          hardwareSetupDeferred: false,
          hasMobileBackup: true,
          mobileBackupDeferred: false,
        ),
        second.execute(
          walletId: initial.walletId,
          hardwareSetupDeferred: false,
          hasMobileBackup: true,
          mobileBackupDeferred: false,
        ),
      ]);

      expect(results, everyElement(isA<Ok<void, BullVaultFailure>>()));
      expect(
        repository.records[initial.walletId]!.status,
        BullVaultLifecycleStatus.active,
      );
      verify(
        () => setHidden.execute(walletId: initial.walletId, isHidden: false),
      ).called(1);
    },
  );

  test(
    'restores initial visibility and state when active save fails',
    () async {
      final initial = _initial().copyWith(
        recoveryPackageConfirmed: true,
        completedHardwareSignerIds: const {'cold'},
      );
      final repository = _RenewalRepository(
        records: {initial.walletId: initial},
        failSaveAt: 2,
      );
      final getWallet = _MockGetWalletUsecase();
      final setHidden = _MockSetWalletHiddenUsecase();
      when(
        () => getWallet.execute(initial.walletId),
      ).thenAnswer((_) async => _initialWallet());
      when(
        () => setHidden.execute(
          walletId: initial.walletId,
          isHidden: any(named: 'isHidden'),
        ),
      ).thenAnswer((_) async {});
      final usecase = ActivateInitialBullVaultUsecase(
        repository,
        getWallet,
        setHidden,
      );

      final result = await usecase.execute(
        walletId: initial.walletId,
        hardwareSetupDeferred: false,
        hasMobileBackup: true,
        mobileBackupDeferred: false,
      );

      expect(result, isA<Err<void, BullVaultFailure>>());
      expect(repository.records[initial.walletId], initial);
      verifyInOrder([
        () => setHidden.execute(walletId: initial.walletId, isHidden: false),
        () => setHidden.execute(walletId: initial.walletId, isHidden: true),
      ]);
    },
  );

  test(
    'retries an activating initial vault with persisted deferrals',
    () async {
      final activating = _initial().copyWith(
        status: BullVaultLifecycleStatus.activating,
        recoveryPackageConfirmed: true,
        hardwareSetupDeferred: true,
        mobileBackupDeferred: true,
      );
      final repository = _RenewalRepository(
        records: {activating.walletId: activating},
      );
      final getWallet = _MockGetWalletUsecase();
      final setHidden = _MockSetWalletHiddenUsecase();
      when(
        () => getWallet.execute(activating.walletId),
      ).thenAnswer((_) async => _initialWallet());
      when(
        () => setHidden.execute(walletId: activating.walletId, isHidden: false),
      ).thenAnswer((_) async {});
      final usecase = ActivateInitialBullVaultUsecase(
        repository,
        getWallet,
        setHidden,
      );

      final result = await usecase.execute(
        walletId: activating.walletId,
        hardwareSetupDeferred: false,
        hasMobileBackup: false,
        mobileBackupDeferred: false,
      );

      expect(result, isA<Ok<void, BullVaultFailure>>());
      final active = repository.records[activating.walletId]!;
      expect(active.status, BullVaultLifecycleStatus.active);
      expect(active.hardwareSetupDeferred, isTrue);
      expect(active.mobileBackupDeferred, isTrue);
    },
  );

  test(
    're-hides an activating initial vault when resume cannot persist',
    () async {
      final activating = _initial().copyWith(
        status: BullVaultLifecycleStatus.activating,
        recoveryPackageConfirmed: true,
      );
      final repository = _RenewalRepository(
        records: {activating.walletId: activating},
        failSaveAt: 1,
      );
      final getWallet = _MockGetWalletUsecase();
      final setHidden = _MockSetWalletHiddenUsecase();
      final reserveAccount = _MockReserveBip48AccountUsecase();
      when(
        () => getWallet.execute(activating.walletId),
      ).thenAnswer((_) async => _initialWallet());
      when(
        () => reserveAccount.execute(
          seedFingerprint: any(named: 'seedFingerprint'),
          coinType: any(named: 'coinType'),
          account: any(named: 'account'),
        ),
      ).thenAnswer((_) async => const Ok(0));
      when(
        () => setHidden.execute(
          walletId: activating.walletId,
          isHidden: any(named: 'isHidden'),
        ),
      ).thenAnswer((_) async {});
      final usecase = ResumeBullVaultOnboardingUsecase(
        repository,
        getWallet,
        setHidden,
        reserveAccount,
      );

      final result = await usecase.execute(
        Network.bitcoinMainnet,
        walletId: activating.walletId,
      );

      expect(result, isA<Err>());
      verifyInOrder([
        () => setHidden.execute(walletId: activating.walletId, isHidden: false),
        () => setHidden.execute(walletId: activating.walletId, isHidden: true),
      ]);
    },
  );
}

BullVaultRecord _previous() => BullVaultRecord(
  walletId: 'wallet-0',
  lineageId: 'lineage',
  vaultGeneration: 0,
  mobileAccount: 0,
  birthHeight: 3_000_000,
  recoveryPackage: testBullVaultRecoveryPackage(lineageId: 'lineage'),
  createdAt: DateTime.utc(2027),
);

BullVaultRecord _replacement({
  Set<String> completedHardwareSignerIds = const {},
  bool recoveryPackageConfirmed = false,
}) => BullVaultRecord(
  walletId: 'wallet-1',
  lineageId: 'lineage',
  vaultGeneration: 1,
  mobileAccount: 0,
  birthHeight: 3_100_000,
  recoveryPackage: testBullVaultRecoveryPackage(
    previousVaultId: 'wallet-0',
    lineageId: 'lineage',
    generation: 1,
  ),
  previousVaultId: 'wallet-0',
  status: BullVaultLifecycleStatus.pending,
  completedHardwareSignerIds: completedHardwareSignerIds,
  recoveryPackageConfirmed: recoveryPackageConfirmed,
  createdAt: DateTime.utc(2028),
);

BullVaultRecord _initial() => BullVaultRecord(
  walletId: 'wallet-initial',
  lineageId: 'initial-lineage',
  vaultGeneration: 0,
  mobileAccount: 0,
  birthHeight: 3_000_000,
  recoveryPackage: testBullVaultRecoveryPackage(lineageId: 'initial-lineage'),
  status: BullVaultLifecycleStatus.pending,
  createdAt: DateTime.utc(2027),
);

Wallet _initialWallet() => Wallet(
  origin: 'wallet-initial',
  network: Network.bitcoinMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: 'deadbeef',
      xpubFingerprint: 'deadbeef',
      xpub: 'xpub-cold',
      derivationPath: "m/48'/0'/0'/2'",
      descriptorPath: '/<0;1>/*',
      signer: SignerEntity.remote,
      signerDevice: null,
      id: 'cold',
    ),
  ],
  scriptType: null,
  publicDescriptor: 'wsh(pk(xpub-cold/<0;1>/*))',
  balanceSat: BigInt.zero,
  isHidden: true,
);

Wallet _replacementWallet({BigInt? balanceSat}) => Wallet(
  origin: 'wallet-1',
  network: Network.bitcoinMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: 'deadbeef',
      xpubFingerprint: 'deadbeef',
      xpub: 'xpub-cold',
      derivationPath: "m/48'/0'/0'/2'",
      descriptorPath: '/<0;1>/*',
      signer: SignerEntity.remote,
      signerDevice: null,
      id: 'cold',
    ),
  ],
  scriptType: null,
  publicDescriptor: 'wsh(pk(xpub-cold/<0;1>/*))',
  balanceSat: balanceSat ?? BigInt.zero,
);

Wallet _previousWallet({bool isHidden = false}) =>
    _replacementWallet().copyWith(origin: 'wallet-0', isHidden: isHidden);
