import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_initial_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/cancel_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault_test_fixture.dart';

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

final class _RenewalRepository extends Fake implements BullVaultRepository {
  final Map<String, BullVaultRecord> records;
  BullVaultRecord? activatedReplacement;

  _RenewalRepository({required this.records});

  @override
  Future<Result<void, BullVaultFailure>> activateInitial(
    BullVaultRecord record,
  ) async {
    records[record.walletId] = record.copyWith(
      status: BullVaultLifecycleStatus.active,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> activateRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord replacement,
  }) async {
    activatedReplacement = replacement;
    records[previous.walletId] = previous.copyWith(
      status: BullVaultLifecycleStatus.migrating,
      successorWalletId: replacement.walletId,
    );
    records[replacement.walletId] = replacement.copyWith(
      status: BullVaultLifecycleStatus.active,
    );
    return const Ok(null);
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
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getWalletLineage(
    String walletId, {
    String? memberWalletId,
  }) async => getLineage(records[walletId]!.lineageId);

  @override
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record) async {
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
  test(
    'retries setup after a wallet read failure without saving progress',
    () async {
      final replacement = _replacement();
      final repository = _RenewalRepository(
        records: {replacement.walletId: replacement},
      );
      final getWallet = _MockGetWalletUsecase();
      when(
        () => getWallet.execute(replacement.walletId),
      ).thenThrow(GetWalletException('Wallet storage unavailable'));
      final usecase = UpdateBullVaultSetupUsecase(repository, getWallet);

      final failed = await usecase.execute(
        walletId: replacement.walletId,
        completedHardwareSignerId: 'cold',
      );

      expect(
        (failed as Err<BullVaultRecord, BullVaultFailure>).failure,
        isA<BullVaultRenewalFailure>(),
      );
      expect(repository.records[replacement.walletId], same(replacement));

      when(
        () => getWallet.execute(replacement.walletId),
      ).thenAnswer((_) async => _replacementWallet());
      final retried = await usecase.execute(
        walletId: replacement.walletId,
        completedHardwareSignerId: 'cold',
      );

      expect(retried, isA<Ok<BullVaultRecord, BullVaultFailure>>());
      expect(
        repository.records[replacement.walletId]!.completedHardwareSignerIds,
        {'cold'},
      );
    },
  );

  test('keeps a renewal pending when the wallet read fails', () async {
    final previous = _previous();
    final replacement = _replacement(
      completedHardwareSignerIds: const {'cold'},
      recoveryPackageConfirmed: true,
    );
    final repository = _RenewalRepository(
      records: {previous.walletId: previous, replacement.walletId: replacement},
    );
    final getWallet = _MockGetWalletUsecase();
    when(
      () => getWallet.execute(replacement.walletId),
    ).thenThrow(GetWalletException('Wallet storage unavailable'));
    final usecase = ActivateBullVaultRenewalUsecase(repository, getWallet);

    final failed = await usecase.execute(
      previousWalletId: previous.walletId,
      replacementWalletId: replacement.walletId,
    );

    expect(
      (failed as Err<void, BullVaultFailure>).failure,
      isA<BullVaultRenewalFailure>(),
    );
    expect(repository.records[previous.walletId], same(previous));
    expect(repository.records[replacement.walletId], same(replacement));
    expect(repository.activatedReplacement, isNull);

    when(
      () => getWallet.execute(replacement.walletId),
    ).thenAnswer((_) async => _replacementWallet());
    final retried = await usecase.execute(
      previousWalletId: previous.walletId,
      replacementWalletId: replacement.walletId,
    );

    expect(retried, isA<Ok<void, BullVaultFailure>>());
    expect(
      repository.records[replacement.walletId]!.status,
      BullVaultLifecycleStatus.active,
    );
  });

  test(
    'keeps initial activation retryable after a wallet read failure',
    () async {
      final initial = _initial().copyWith(recoveryPackageConfirmed: true);
      final repository = _RenewalRepository(
        records: {initial.walletId: initial},
      );
      final getWallet = _MockGetWalletUsecase();
      when(
        () => getWallet.execute(initial.walletId),
      ).thenThrow(GetWalletException('Wallet storage unavailable'));
      final usecase = ActivateInitialBullVaultUsecase(repository, getWallet);

      final failed = await usecase.execute(
        walletId: initial.walletId,
        hardwareSetupDeferred: true,
        hasMobileBackup: true,
        mobileBackupDeferred: false,
      );

      expect(
        (failed as Err<void, BullVaultFailure>).failure,
        isA<BullVaultCreationFailure>(),
      );
      expect(repository.records[initial.walletId], same(initial));

      when(
        () => getWallet.execute(initial.walletId),
      ).thenAnswer((_) async => _initialWallet());
      final retried = await usecase.execute(
        walletId: initial.walletId,
        hardwareSetupDeferred: true,
        hasMobileBackup: true,
        mobileBackupDeferred: false,
      );

      expect(retried, isA<Ok<void, BullVaultFailure>>());
      expect(
        repository.records[initial.walletId]!.status,
        BullVaultLifecycleStatus.active,
      );
    },
  );

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
    final usecase = ActivateBullVaultRenewalUsecase(repository, getWallet);

    final result = await usecase.execute(
      previousWalletId: previous.walletId,
      replacementWalletId: replacement.walletId,
    );

    expect(result, isA<Ok<void, BullVaultFailure>>());
  });

  test('does not resume a completed renewal', () async {
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

    when(
      () => getWallet.execute(replacement.walletId),
    ).thenAnswer((_) async => _replacementWallet());
    when(
      () => getWallet.execute(previous.walletId),
    ).thenAnswer((_) async => _previousWallet(isHidden: true));
    final usecase = ResumeBullVaultRenewalUsecase(repository, getWallet);

    final result = await usecase.execute(replacement.walletId);

    expect(
      (result as Ok<BullVaultRenewResult?, BullVaultFailure>).value,
      isNull,
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

    when(
      () => getWallet.execute(replacement.walletId),
    ).thenAnswer((_) async => _replacementWallet());
    final usecase = ActivateBullVaultRenewalUsecase(repository, getWallet);

    final result = await usecase.execute(
      previousWalletId: previous.walletId,
      replacementWalletId: replacement.walletId,
    );

    expect(result, isA<Ok<void, BullVaultFailure>>());
    expect(repository.activatedReplacement!.hardwareSetupComplete, isTrue);
  });

  test(
    'resumes a second renewal from either the active or prepared wallet',
    () async {
      final first = testBullVaultCreateResult(
        walletId: 'first',
        status: BullVaultLifecycleStatus.active,
      );
      final second = testBullVaultCreateResult(
        walletId: 'second',
        generation: 1,
        lineageId: first.policy.lineageId,
        previousVaultId: first.wallet.id,
        status: BullVaultLifecycleStatus.active,
      );
      final third = testBullVaultCreateResult(
        walletId: 'third',
        generation: 2,
        lineageId: first.policy.lineageId,
        previousVaultId: second.wallet.id,
      );
      final repository = _RenewalRepository(
        records: {
          first.wallet.id: first.record.copyWith(
            status: BullVaultLifecycleStatus.migrating,
            successorWalletId: second.wallet.id,
          ),
          second.wallet.id: second.record.copyWith(
            recoveryPackageConfirmed: true,
          ),
          third.wallet.id: third.record,
        },
      );
      final wallets = {
        first.wallet.id: first.wallet.copyWith(isHidden: true),
        second.wallet.id: second.wallet,
        third.wallet.id: third.wallet,
      };
      final getWallet = _MockGetWalletUsecase();
      when(() => getWallet.execute(any())).thenAnswer(
        (invocation) async => wallets[invocation.positionalArguments.single],
      );
      final resume = ResumeBullVaultRenewalUsecase(repository, getWallet);
      for (final walletId in [second.wallet.id, third.wallet.id]) {
        final result = await resume.execute(walletId);
        expect((result as Ok).value.replacement.wallet.id, third.wallet.id);
      }
      expect(repository.records.keys, unorderedEquals(wallets.keys));
    },
  );

  test(
    'rejects a replacement whose wallet descriptor does not match',
    () async {
      final previous = _previous();
      final replacement = _replacement().copyWith(
        status: BullVaultLifecycleStatus.pending,
      );
      final repository = _RenewalRepository(
        records: {
          previous.walletId: previous,
          replacement.walletId: replacement,
        },
      );
      final getWallet = _MockGetWalletUsecase();

      when(() => getWallet.execute(replacement.walletId)).thenAnswer(
        (_) async =>
            _replacementWallet().copyWith(publicDescriptor: 'unexpected'),
      );
      final usecase = ResumeBullVaultRenewalUsecase(repository, getWallet);

      final result = await usecase.execute(previous.walletId);

      expect(result, isA<Err>());
    },
  );

  test(
    'keeps an initial vault hidden until mandatory setup is persisted',
    () async {
      final initial = _initial().copyWith(recoveryPackageConfirmed: true);
      final repository = _RenewalRepository(
        records: {initial.walletId: initial},
      );
      final getWallet = _MockGetWalletUsecase();

      when(
        () => getWallet.execute(initial.walletId),
      ).thenAnswer((_) async => _initialWallet());
      final usecase = ActivateInitialBullVaultUsecase(repository, getWallet);

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
    },
  );

  test('activates a hardware-only vault without a mobile backup', () async {
    final created = testBullVaultCreateResult(
      walletId: 'hardware-initial',
      usesBullMobile: false,
    );
    final initial = created.record.copyWith(
      recoveryPackageConfirmed: true,
      completedHardwareSignerIds: const {'everyday', 'cold'},
    );
    final wallet = created.wallet.copyWith(
      signers: [
        WalletSigner.single(
          id: 'everyday',
          signer: SignerEntity.remote,
          signerDevice: null,
          masterFingerprint: '11111111',
          xpubFingerprint: '11111111',
          xpub: 'xpub-everyday',
          derivationPath: "m/48'/0'/0'/2'",
          descriptorPath: '/<0;1>/*',
        ),
        WalletSigner.single(
          id: 'cold',
          signer: SignerEntity.remote,
          signerDevice: null,
          masterFingerprint: '22222222',
          xpubFingerprint: '22222222',
          xpub: 'xpub-cold',
          derivationPath: "m/48'/0'/0'/2'",
          descriptorPath: '/<0;1>/*',
        ),
      ],
    );
    final repository = _RenewalRepository(records: {initial.walletId: initial});
    final getWallet = _MockGetWalletUsecase();

    when(
      () => getWallet.execute(initial.walletId),
    ).thenAnswer((_) async => wallet);

    final result = await ActivateInitialBullVaultUsecase(repository, getWallet)
        .execute(
          walletId: initial.walletId,
          hardwareSetupDeferred: false,
          hasMobileBackup: false,
          mobileBackupDeferred: false,
        );

    expect(result, isA<Ok<void, BullVaultFailure>>());
    expect(
      repository.records[initial.walletId]?.status,
      BullVaultLifecycleStatus.active,
    );
  });
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

BullVaultRecord _initial({String? mobileSeedFingerprint}) => BullVaultRecord(
  walletId: 'wallet-initial',
  lineageId: 'initial-lineage',
  vaultGeneration: 0,
  mobileAccount: 0,
  mobileSeedFingerprint: mobileSeedFingerprint,
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
