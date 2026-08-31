import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bip48_account_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_wallet_hidden_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_recovery_package_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_descriptor_service.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault_test_fixture.dart';
import '../../../../core_test/wallet/bdk_wallet_test_fixture.dart';

const _fourthMnemonic = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';

final class _TestRepository implements BullVaultRepository {
  final BullVaultRecoveryPackageCodec _codec;
  final Map<String, BullVaultRecord> records = {};
  BullVaultFailure? saveFailure;
  BullVaultFailure? deleteFailure;

  _TestRepository(this._codec);

  @override
  Result<BullVaultRecoveryPackage, BullVaultFailure> decodeRecoveryPackage(
    String source,
  ) {
    try {
      return Ok(_codec.decode(source));
    } on FormatException {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
  }

  @override
  String encodeRecoveryPackage(BullVaultRecoveryPackage recoveryPackage) =>
      _codec.encode(recoveryPackage);

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String walletId,
  ) async => Ok(records[walletId]);

  @override
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record) async {
    if (saveFailure case final failure?) return Err(failure);
    records[record.walletId] = record;
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> delete(String walletId) async {
    if (deleteFailure case final failure?) return Err(failure);
    records.remove(walletId);
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> activateRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord replacement,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> linkRestoredRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord successor,
  }) async {
    records[previous.walletId] = previous.copyWith(
      successorWalletId: successor.walletId,
      status: BullVaultLifecycleStatus.migrating,
    );
    records[successor.walletId] = successor;
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> cancelRenewal({
    required String previousWalletId,
    required String replacementWalletId,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getIncompleteInitial(
    Network network,
  ) => throw UnimplementedError();

  @override
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getLineage(
    String lineageId,
  ) async => Ok([
    for (final record in records.values)
      if (record.lineageId == lineageId) record,
  ]);

  @override
  Future<Result<int, BullVaultFailure>> reserveNextGeneration(
    BullVaultRecord current,
  ) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> releaseGeneration({
    required String lineageId,
    required int generation,
  }) => throw UnimplementedError();
}

class _MockSeedVerificationPort extends Mock implements SeedVerificationPort {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockReserveBip48AccountUsecase extends Mock
    implements ReserveBip48AccountUsecase {}

class _MockDeleteWalletUsecase extends Mock implements DeleteWalletUsecase {}

class _MockSetWalletHiddenUsecase extends Mock
    implements SetWalletHiddenUsecase {}

final class _ParsingDescriptorPort implements BitcoinDescriptorPort {
  WalletAlreadyExistsException? duplicate;
  Wallet? importedWallet;

  @override
  ({
    String descriptor,
    ScriptType? scriptType,
    List<WalletDescriptorKey> descriptorKeys,
    bool inferredChangePath,
  })
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) => parseTestBullVaultDescriptor(descriptor: descriptor, network: network);

  @override
  ({List<WalletDescriptorKey> policyKeys, bool hasUnspendablePolicyKey})
  analyzeBitcoinPolicyDescriptor({
    required String descriptor,
    required Network network,
  }) => throw UnimplementedError();

  @override
  Future<Wallet> importDescriptor({
    required String descriptor,
    required Network network,
    required String label,
    List<WalletSigner> signers = const [],
    bool isHidden = false,
    bool sync = false,
  }) async {
    if (duplicate case final error?) throw error;
    return importedWallet = Wallet(
      origin: 'bullvault-wallet',
      label: label,
      network: network,
      signers: signers,
      scriptType: null,
      publicDescriptor: descriptor,
      balanceSat: BigInt.zero,
      isHidden: isHidden,
    );
  }
}

void main() {
  late BullVaultRecoveryPackageCodec codec;
  late BullVaultDescriptorService descriptorService;
  late _TestRepository repository;
  late _ParsingDescriptorPort descriptorPort;
  late _MockSeedVerificationPort seedVerification;
  late _MockGetSettingsUsecase getSettings;
  late _MockGetWalletUsecase getWallet;
  late _MockReserveBip48AccountUsecase reserveAccount;
  late _MockDeleteWalletUsecase deleteWallet;
  late _MockSetWalletHiddenUsecase setWalletHidden;
  late RestoreBullVaultUsecase usecase;
  late List<BullVaultSignerKey> signers;
  late BullVaultPolicy policy;

  setUp(() {
    descriptorPort = _ParsingDescriptorPort();
    seedVerification = _MockSeedVerificationPort();
    descriptorService = BullVaultDescriptorService(
      descriptorPort,
      seedVerification,
    );
    codec = BullVaultRecoveryPackageCodec(descriptorService);
    repository = _TestRepository(codec);
    getSettings = _MockGetSettingsUsecase();
    getWallet = _MockGetWalletUsecase();
    reserveAccount = _MockReserveBip48AccountUsecase();
    deleteWallet = _MockDeleteWalletUsecase();
    setWalletHidden = _MockSetWalletHiddenUsecase();
    usecase = RestoreBullVaultUsecase(
      repository,
      descriptorPort,
      descriptorService,
      getSettings,
      getWallet,
      reserveAccount,
      deleteWallet,
      setWalletHidden,
    );
    signers = [
      _signer(BullVaultSignerRole.everyday, deriveSignerKeys(testMnemonics[0])),
      _signer(BullVaultSignerRole.cold, deriveSignerKeys(testMnemonics[1])),
    ];
    final createdAt = DateTime.utc(2027, 1, 15, 12);
    final descriptor = BullVaultPolicy.descriptorTemplate(
      vaultGeneration: 0,
      network: Network.bitcoinTestnet,
      protection: BullVaultProtection.standard,
      everydayKey: signers[0],
      coldKey: signers[1],
      secondColdKey: null,
      inheritanceKey: null,
      schedule: BullVaultSchedule.standardWithoutInheritance,
      referenceTime: createdAt,
    );
    policy = BullVaultPolicy.build(
      vaultGeneration: 0,
      network: Network.bitcoinTestnet,
      descriptor: descriptorPort
          .parseBitcoinDescriptor(
            descriptor: descriptor,
            network: Network.bitcoinTestnet,
          )
          .descriptor,
      protection: BullVaultProtection.standard,
      everydayKey: signers[0],
      coldKey: signers[1],
      secondColdKey: null,
      inheritanceKey: null,
      schedule: BullVaultSchedule.standardWithoutInheritance,
      timeReference: BullVaultTimeReference(
        deviceTime: createdAt,
        chainHeight: 3_000_000,
        medianTimePast:
            createdAt
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      ),
    );
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => seedVerification.matchesXpubs(
        fingerprint: any(named: 'fingerprint'),
        keys: any(named: 'keys'),
      ),
    ).thenAnswer(
      (invocation) async =>
          invocation.namedArguments[#fingerprint] ==
          signers[0].accountKey.masterFingerprint,
    );
    when(
      () => reserveAccount.execute(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
        account: any(named: 'account'),
      ),
    ).thenAnswer((_) async => const Ok(0));
    when(
      () => deleteWallet.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
    when(
      () => setWalletHidden.execute(
        walletId: any(named: 'walletId'),
        isHidden: any(named: 'isHidden'),
      ),
    ).thenAnswer((_) async {});
  });

  test(
    'uses the imported wallet identity when restoring package metadata',
    () async {
      final package = BullVaultRecoveryPackage(policy: policy);
      final result = await usecase.execute(
        kind: BullVaultRestoreInputKind.recoveryPackage,
        source: codec.encode(package),
        label: 'Restored vault',
      );

      expect(result, isA<Ok<BullVaultRestoreResult, BullVaultFailure>>());
      final restored =
          (result as Ok<BullVaultRestoreResult, BullVaultFailure>).value;
      expect(restored.source, BullVaultRestoreSource.recoveryPackage);
      expect(
        restored.record.recoveryPackage.policy.schedule?.coldYears,
        policy.schedule?.coldYears,
      );
      expect(
        restored.record.recoveryPackage.policy.schedule?.recoveryYears,
        policy.schedule?.recoveryYears,
      );
      expect(restored.record.mobileAccount, 0);
      verify(
        () => reserveAccount.execute(
          seedFingerprint: signers[0].accountKey.masterFingerprint,
          coinType: 1,
          account: 0,
        ),
      ).called(1);
      expect(descriptorPort.importedWallet!.isHidden, isTrue);
      verify(
        () => setWalletHidden.execute(
          walletId: restored.wallet.id,
          isHidden: false,
        ),
      ).called(1);
    },
  );

  test('serializes restore workflows across use case instances', () async {
    final firstSettingsCall = Completer<void>();
    final releaseFirstCall = Completer<void>();
    addTearDown(() {
      if (!releaseFirstCall.isCompleted) releaseFirstCall.complete();
    });
    var settingsCalls = 0;
    var activeSettingsCalls = 0;
    var maxActiveSettingsCalls = 0;
    when(() => getSettings.execute()).thenAnswer((_) async {
      settingsCalls++;
      activeSettingsCalls++;
      if (activeSettingsCalls > maxActiveSettingsCalls) {
        maxActiveSettingsCalls = activeSettingsCalls;
      }
      if (settingsCalls == 1) {
        firstSettingsCall.complete();
        await releaseFirstCall.future;
      }
      activeSettingsCalls--;
      return const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      );
    });
    final otherUsecase = RestoreBullVaultUsecase(
      repository,
      descriptorPort,
      descriptorService,
      getSettings,
      getWallet,
      reserveAccount,
      deleteWallet,
      setWalletHidden,
    );
    final package = codec.encode(BullVaultRecoveryPackage(policy: policy));

    final first = usecase.execute(
      kind: BullVaultRestoreInputKind.recoveryPackage,
      source: package,
      label: 'Restored vault',
    );
    await firstSettingsCall.future;
    final second = otherUsecase.execute(
      kind: BullVaultRestoreInputKind.recoveryPackage,
      source: package,
      label: 'Same restored vault',
    );
    await Future<void>.delayed(Duration.zero);

    expect(settingsCalls, 1);
    releaseFirstCall.complete();
    final results = await Future.wait([first, second]);

    expect(results, everyElement(isA<Ok>()));
    expect(maxActiveSettingsCalls, 1);
    expect(repository.records, hasLength(1));
  });

  test(
    'keeps a staged restore resumable when publication is interrupted',
    () async {
      final package = BullVaultRecoveryPackage(policy: policy);
      var attempts = 0;
      when(
        () => setWalletHidden.execute(
          walletId: 'bullvault-wallet',
          isHidden: false,
        ),
      ).thenAnswer((_) async {
        if (attempts++ == 0) throw Exception('interrupted publication');
      });

      final first = await usecase.execute(
        kind: BullVaultRestoreInputKind.recoveryPackage,
        source: codec.encode(package),
        label: 'Restored vault',
      );

      expect(first, isA<Err<BullVaultRestoreResult, BullVaultFailure>>());
      expect(repository.records, contains('bullvault-wallet'));
      verifyNever(() => deleteWallet.execute(walletId: 'bullvault-wallet'));

      final stagedWallet = descriptorPort.importedWallet!;
      descriptorPort.duplicate = const WalletAlreadyExistsException(
        'bullvault-wallet',
      );
      when(
        () => getWallet.execute('bullvault-wallet'),
      ).thenAnswer((_) async => stagedWallet);

      final retried = await usecase.execute(
        kind: BullVaultRestoreInputKind.recoveryPackage,
        source: codec.encode(package),
        label: 'Restored vault',
      );

      expect(retried, isA<Ok<BullVaultRestoreResult, BullVaultFailure>>());
      verify(
        () => setWalletHidden.execute(
          walletId: 'bullvault-wallet',
          isHidden: false,
        ),
      ).called(2);
    },
  );

  test('does not infer schedule metadata absent from a descriptor', () async {
    final result = await usecase.execute(
      kind: BullVaultRestoreInputKind.descriptor,
      source: policy.descriptor,
      label: 'Descriptor vault',
    );

    expect(result, isA<Ok<BullVaultRestoreResult, BullVaultFailure>>());
    final restored =
        (result as Ok<BullVaultRestoreResult, BullVaultFailure>).value;
    expect(restored.source, BullVaultRestoreSource.descriptor);
    expect(restored.record.recoveryPackage.policy.schedule, isNull);
    expect(
      restored.record.recoveryPackage.policy.renewalSchedule,
      same(BullVaultSchedule.standardWithoutInheritance),
    );
    expect(
      restored.record.recoveryPackage.policy.coldActivationTimestamp,
      policy.coldActivationTimestamp,
    );
  });

  test(
    'upgrades a descriptor restore with recovery package metadata',
    () async {
      final first = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: policy.descriptor,
        label: 'Descriptor vault',
      );
      final wallet =
          (first as Ok<BullVaultRestoreResult, BullVaultFailure>).value.wallet;
      descriptorPort.duplicate = WalletAlreadyExistsException(wallet.id);
      when(() => getWallet.execute(wallet.id)).thenAnswer((_) async => wallet);

      final second = await usecase.execute(
        kind: BullVaultRestoreInputKind.recoveryPackage,
        source: codec.encode(BullVaultRecoveryPackage(policy: policy)),
        label: 'Restored vault',
      );

      final restored =
          (second as Ok<BullVaultRestoreResult, BullVaultFailure>).value.record;
      expect(restored.recoveryPackageConfirmed, isTrue);
      expect(restored.lineageId, policy.lineageId);
      expect(restored.birthHeight, policy.birthHeight);
      expect(
        restored.recoveryPackage.policy.schedule?.coldYears,
        policy.schedule?.coldYears,
      );
      expect(
        restored.recoveryPackage.policy.schedule?.recoveryYears,
        policy.schedule?.recoveryYears,
      );
      expect(repository.records[wallet.id], same(restored));
    },
  );

  test('recognizes every supported BullVault profile exactly', () async {
    final allSigners = [
      _signer(BullVaultSignerRole.everyday, deriveSignerKeys(testMnemonics[0])),
      _signer(BullVaultSignerRole.cold, deriveSignerKeys(testMnemonics[1])),
      _signer(
        BullVaultSignerRole.secondCold,
        deriveSignerKeys(testMnemonics[2]),
      ),
      _signer(
        BullVaultSignerRole.inheritance,
        deriveSignerKeys(_fourthMnemonic),
      ),
    ];
    for (final (protection, includesInheritance) in [
      (BullVaultProtection.standard, false),
      (BullVaultProtection.standard, true),
      (BullVaultProtection.extra, false),
      (BullVaultProtection.extra, true),
    ]) {
      final schedule = BullVaultSchedule.defaultsFor(
        protection: protection,
        includesInheritance: includesInheritance,
      );
      final descriptor = BullVaultPolicy.descriptorTemplate(
        vaultGeneration: 0,
        network: Network.bitcoinTestnet,
        protection: protection,
        everydayKey: allSigners[0],
        coldKey: allSigners[1],
        secondColdKey: protection.usesTwoColdKeys ? allSigners[2] : null,
        inheritanceKey: includesInheritance
            ? allSigners[protection.usesTwoColdKeys ? 3 : 2]
            : null,
        schedule: schedule,
        referenceTime: DateTime.utc(2027, 1, 15, 12),
      );

      final result = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: descriptor,
        label: 'Profile vault',
      );

      expect(result, isA<Ok<BullVaultRestoreResult, BullVaultFailure>>());
      final restored =
          (result as Ok<BullVaultRestoreResult, BullVaultFailure>).value;
      expect(restored.record.recoveryPackage.policy.protection, protection);
      expect(
        restored.record.recoveryPackage.policy.inheritanceKey != null,
        includesInheritance,
      );
      expect(
        restored.record.recoveryPackage.policy.secondColdKey != null,
        protection.usesTwoColdKeys,
      );
      repository.records.clear();
    }
  });

  test('rejects a descriptor whose mobile xpub is not held by Bull', () async {
    when(
      () => seedVerification.matchesXpubs(
        fingerprint: any(named: 'fingerprint'),
        keys: any(named: 'keys'),
      ),
    ).thenAnswer((_) async => false);

    final result = await usecase.execute(
      kind: BullVaultRestoreInputKind.descriptor,
      source: policy.descriptor,
      label: 'Wrong seed',
    );

    expect(
      result,
      isA<Err<BullVaultRestoreResult, BullVaultFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<BullVaultInvalidRecoveryFailure>(),
      ),
    );
    expect(repository.records, isEmpty);
  });

  test('rejects inconsistent predecessor metadata in a package', () async {
    final package = BullVaultRecoveryPackage(
      previousVaultId: 'unexpected-predecessor',
      policy: policy,
    );

    final result = await usecase.execute(
      kind: BullVaultRestoreInputKind.recoveryPackage,
      source: codec.encode(package),
      label: 'Invalid lineage',
    );

    expect(
      result,
      isA<Err<BullVaultRestoreResult, BullVaultFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<BullVaultInvalidRecoveryFailure>(),
      ),
    );
    expect(repository.records, isEmpty);
  });

  test('rejects a renewed package beside its active predecessor', () async {
    const previousWalletId = 'previous-wallet';
    repository.records[previousWalletId] = BullVaultRecord(
      walletId: previousWalletId,
      lineageId: policy.lineageId,
      vaultGeneration: policy.vaultGeneration,
      mobileAccount: 0,
      birthHeight: policy.birthHeight,
      recoveryPackage: BullVaultRecoveryPackage(policy: policy),
      status: BullVaultLifecycleStatus.active,
      recoveryPackageConfirmed: true,
      createdAt: policy.createdAt!,
    );
    final renewedPolicy = _renewedPolicy(
      descriptorPort: descriptorPort,
      signers: signers,
      lineageId: policy.lineageId,
    );

    final result = await usecase.execute(
      kind: BullVaultRestoreInputKind.recoveryPackage,
      source: codec.encode(
        BullVaultRecoveryPackage(
          previousVaultId: previousWalletId,
          policy: renewedPolicy,
        ),
      ),
      label: 'Renewed vault',
    );

    expect(result, isA<Err<BullVaultRestoreResult, BullVaultFailure>>());
    expect(
      repository.records[previousWalletId]!.status,
      BullVaultLifecycleStatus.active,
    );
    expect(repository.records, hasLength(1));
    verify(() => deleteWallet.execute(walletId: 'bullvault-wallet')).called(1);
  });

  test(
    'links a renewed descriptor restore when its package is added',
    () async {
      const previousWalletId = 'previous-wallet';
      repository.records[previousWalletId] = BullVaultRecord(
        walletId: previousWalletId,
        lineageId: policy.lineageId,
        vaultGeneration: policy.vaultGeneration,
        mobileAccount: 0,
        birthHeight: policy.birthHeight,
        recoveryPackage: BullVaultRecoveryPackage(policy: policy),
        status: BullVaultLifecycleStatus.active,
        recoveryPackageConfirmed: true,
        createdAt: policy.createdAt!,
      );
      final renewedPolicy = _renewedPolicy(
        descriptorPort: descriptorPort,
        signers: signers,
        lineageId: policy.lineageId,
      );
      final first = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: renewedPolicy.descriptor,
        label: 'Renewed descriptor',
      );
      final wallet =
          (first as Ok<BullVaultRestoreResult, BullVaultFailure>).value.wallet;
      descriptorPort.duplicate = WalletAlreadyExistsException(wallet.id);
      when(() => getWallet.execute(wallet.id)).thenAnswer((_) async => wallet);

      final second = await usecase.execute(
        kind: BullVaultRestoreInputKind.recoveryPackage,
        source: codec.encode(
          BullVaultRecoveryPackage(
            previousVaultId: previousWalletId,
            policy: renewedPolicy,
          ),
        ),
        label: 'Renewed vault',
      );

      final restored =
          (second as Ok<BullVaultRestoreResult, BullVaultFailure>).value.record;
      expect(restored.recoveryPackageConfirmed, isTrue);
      expect(restored.lineageId, policy.lineageId);
      expect(restored.previousVaultId, previousWalletId);
      expect(
        repository.records[previousWalletId]!.status,
        BullVaultLifecycleStatus.migrating,
      );
      expect(
        repository.records[previousWalletId]!.successorWalletId,
        wallet.id,
      );
      verify(
        () =>
            setWalletHidden.execute(walletId: previousWalletId, isHidden: true),
      ).called(1);
    },
  );

  test(
    'does not link a renewed descriptor with different signer keys',
    () async {
      const previousWalletId = 'previous-wallet';
      repository.records[previousWalletId] = BullVaultRecord(
        walletId: previousWalletId,
        lineageId: policy.lineageId,
        vaultGeneration: policy.vaultGeneration,
        mobileAccount: 0,
        birthHeight: policy.birthHeight,
        recoveryPackage: BullVaultRecoveryPackage(policy: policy),
        status: BullVaultLifecycleStatus.active,
        recoveryPackageConfirmed: true,
        createdAt: policy.createdAt!,
      );
      final renewedPolicy = _renewedPolicy(
        descriptorPort: descriptorPort,
        signers: [
          signers[0],
          _signer(BullVaultSignerRole.cold, deriveSignerKeys(testMnemonics[2])),
        ],
        lineageId: policy.lineageId,
      );
      final first = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: renewedPolicy.descriptor,
        label: 'Renewed descriptor',
      );
      final firstResult =
          (first as Ok<BullVaultRestoreResult, BullVaultFailure>).value;
      final wallet = firstResult.wallet;
      descriptorPort.duplicate = WalletAlreadyExistsException(wallet.id);
      when(() => getWallet.execute(wallet.id)).thenAnswer((_) async => wallet);

      final second = await usecase.execute(
        kind: BullVaultRestoreInputKind.recoveryPackage,
        source: codec.encode(
          BullVaultRecoveryPackage(
            previousVaultId: previousWalletId,
            policy: renewedPolicy,
          ),
        ),
        label: 'Renewed vault',
      );

      expect(second, isA<Err<BullVaultRestoreResult, BullVaultFailure>>());
      expect(repository.records[wallet.id]!.recoveryPackageConfirmed, isFalse);
      expect(
        repository.records[wallet.id]!.lineageId,
        firstResult.record.lineageId,
      );
      expect(
        repository.records[previousWalletId]!.status,
        BullVaultLifecycleStatus.active,
      );
    },
  );

  test(
    'adopts an existing compatible wallet without importing a duplicate',
    () async {
      descriptorPort.duplicate = const WalletAlreadyExistsException(
        'existing-wallet',
      );
      final existing = _compatibleExistingWallet(
        descriptorPort: descriptorPort,
        policy: policy,
        signers: signers,
      );
      when(
        () => getWallet.execute('existing-wallet'),
      ).thenAnswer((_) async => existing);

      final result = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: policy.descriptor,
        label: 'Ignored replacement label',
      );

      expect(result, isA<Ok<BullVaultRestoreResult, BullVaultFailure>>());
      expect(
        (result as Ok<BullVaultRestoreResult, BullVaultFailure>)
            .value
            .wallet
            .id,
        'existing-wallet',
      );
      verifyNever(() => deleteWallet.execute(walletId: any(named: 'walletId')));
    },
  );

  test('does not publish an inactive existing BullVault', () async {
    descriptorPort.duplicate = const WalletAlreadyExistsException(
      'existing-wallet',
    );
    final existing = _compatibleExistingWallet(
      descriptorPort: descriptorPort,
      policy: policy,
      signers: signers,
    );
    when(
      () => getWallet.execute('existing-wallet'),
    ).thenAnswer((_) async => existing);

    for (final status in [
      BullVaultLifecycleStatus.pending,
      BullVaultLifecycleStatus.cancelled,
    ]) {
      repository.records['existing-wallet'] = BullVaultRecord(
        walletId: 'existing-wallet',
        lineageId: policy.lineageId,
        vaultGeneration: policy.vaultGeneration,
        mobileAccount: 0,
        birthHeight: policy.birthHeight,
        recoveryPackage: BullVaultRecoveryPackage(policy: policy),
        status: status,
        createdAt: policy.createdAt!,
      );

      final result = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: policy.descriptor,
        label: 'Restored vault',
      );

      expect(result, isA<Err<BullVaultRestoreResult, BullVaultFailure>>());
    }
    verifyNever(
      () => setWalletHidden.execute(
        walletId: any(named: 'walletId'),
        isHidden: any(named: 'isHidden'),
      ),
    );
  });

  test('does not delete an adopted wallet when metadata save fails', () async {
    repository.saveFailure = const BullVaultCreationFailure();
    descriptorPort.duplicate = const WalletAlreadyExistsException(
      'existing-wallet',
    );
    final existing = _compatibleExistingWallet(
      descriptorPort: descriptorPort,
      policy: policy,
      signers: signers,
    );
    when(
      () => getWallet.execute('existing-wallet'),
    ).thenAnswer((_) async => existing);

    final result = await usecase.execute(
      kind: BullVaultRestoreInputKind.descriptor,
      source: policy.descriptor,
      label: 'Restored vault',
    );

    expect(result, isA<Err<BullVaultRestoreResult, BullVaultFailure>>());
    verifyNever(() => deleteWallet.execute(walletId: any(named: 'walletId')));
  });

  test(
    'repairs the mobile-account reservation when restore is retried',
    () async {
      final first = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: policy.descriptor,
        label: 'Restored vault',
      );
      final wallet =
          (first as Ok<BullVaultRestoreResult, BullVaultFailure>).value.wallet;
      clearInteractions(reserveAccount);
      descriptorPort.duplicate = WalletAlreadyExistsException(wallet.id);
      when(() => getWallet.execute(wallet.id)).thenAnswer((_) async => wallet);

      final retried = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: policy.descriptor,
        label: 'Restored vault',
      );

      expect(retried, isA<Ok<BullVaultRestoreResult, BullVaultFailure>>());
      verify(
        () => reserveAccount.execute(
          seedFingerprint: signers[0].accountKey.masterFingerprint,
          coinType: 1,
          account: 0,
        ),
      ).called(1);
    },
  );

  test('removes a new wallet when metadata cannot be saved', () async {
    repository.saveFailure = const BullVaultCreationFailure();

    final result = await usecase.execute(
      kind: BullVaultRestoreInputKind.descriptor,
      source: policy.descriptor,
      label: 'Restored vault',
    );

    expect(result, isA<Err<BullVaultRestoreResult, BullVaultFailure>>());
    verify(() => deleteWallet.execute(walletId: 'bullvault-wallet')).called(1);
  });

  test(
    'preserves the account when a restored wallet cannot be removed',
    () async {
      repository.saveFailure = const BullVaultCreationFailure();
      when(
        () => deleteWallet.execute(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('wallet deletion failed'));

      final result = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: policy.descriptor,
        label: 'Restored vault',
      );

      expect(result, isA<Err<BullVaultRestoreResult, BullVaultFailure>>());
      verify(
        () => reserveAccount.execute(
          seedFingerprint: signers[0].accountKey.masterFingerprint,
          coinType: 1,
          account: 0,
        ),
      ).called(1);
    },
  );

  test(
    'rolls back metadata and wallet when account reservation fails',
    () async {
      when(
        () => reserveAccount.execute(
          seedFingerprint: any(named: 'seedFingerprint'),
          coinType: any(named: 'coinType'),
          account: any(named: 'account'),
        ),
      ).thenAnswer((_) async => const Err(Bip48AccountAllocationFailure()));

      final result = await usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: policy.descriptor,
        label: 'Restored vault',
      );

      expect(result, isA<Err<BullVaultRestoreResult, BullVaultFailure>>());
      expect(repository.records, isEmpty);
      verify(
        () => deleteWallet.execute(walletId: 'bullvault-wallet'),
      ).called(1);
    },
  );

  test('keeps a new wallet when metadata rollback fails', () async {
    repository.deleteFailure = const BullVaultCreationFailure();
    when(
      () => reserveAccount.execute(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
        account: any(named: 'account'),
      ),
    ).thenAnswer((_) async => const Err(Bip48AccountAllocationFailure()));

    final result = await usecase.execute(
      kind: BullVaultRestoreInputKind.descriptor,
      source: policy.descriptor,
      label: 'Restored vault',
    );

    expect(result, isA<Err<BullVaultRestoreResult, BullVaultFailure>>());
    expect(repository.records, contains('bullvault-wallet'));
    verifyNever(() => deleteWallet.execute(walletId: any(named: 'walletId')));
  });
}

BullVaultPolicy _renewedPolicy({
  required _ParsingDescriptorPort descriptorPort,
  required List<BullVaultSignerKey> signers,
  required String lineageId,
}) {
  final renewedAt = DateTime.utc(2028, 1, 15, 12);
  final descriptor = BullVaultPolicy.descriptorTemplate(
    vaultGeneration: 1,
    network: Network.bitcoinTestnet,
    protection: BullVaultProtection.standard,
    everydayKey: signers[0],
    coldKey: signers[1],
    secondColdKey: null,
    inheritanceKey: null,
    schedule: BullVaultSchedule.standardWithoutInheritance,
    referenceTime: renewedAt,
  );
  return BullVaultPolicy.build(
    lineageId: lineageId,
    vaultGeneration: 1,
    network: Network.bitcoinTestnet,
    descriptor: descriptorPort
        .parseBitcoinDescriptor(
          descriptor: descriptor,
          network: Network.bitcoinTestnet,
        )
        .descriptor,
    protection: BullVaultProtection.standard,
    everydayKey: signers[0],
    coldKey: signers[1],
    secondColdKey: null,
    inheritanceKey: null,
    schedule: BullVaultSchedule.standardWithoutInheritance,
    timeReference: BullVaultTimeReference(
      deviceTime: renewedAt,
      chainHeight: 3_100_000,
      medianTimePast:
          renewedAt.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    ),
  );
}

BullVaultSignerKey _signer(
  BullVaultSignerRole role,
  SignerDescriptorKeys keys,
) => BullVaultSignerKey(
  role: role,
  accountKey: WalletDescriptorKey(
    id: '${role.name}-account',
    signerId: role.name,
    masterFingerprint: keys.fingerprint,
    xpubFingerprint: keys.fingerprint,
    xpub: keys.xpub.split(']').last,
    derivationPath: "m/48'/1'/0'/2'",
  ),
  signer: role == BullVaultSignerRole.everyday
      ? SignerEntity.local
      : SignerEntity.remote,
  signerDevice: null,
);

Wallet _compatibleExistingWallet({
  required _ParsingDescriptorPort descriptorPort,
  required BullVaultPolicy policy,
  required List<BullVaultSignerKey> signers,
}) {
  final parsed = descriptorPort.parseBitcoinDescriptor(
    descriptor: policy.descriptor,
    network: Network.bitcoinTestnet,
  );
  return Wallet(
    origin: 'existing-wallet',
    label: 'Existing',
    network: Network.bitcoinTestnet,
    signers: [
      WalletSigner(
        id: 'existing-local-signer',
        signer: SignerEntity.local,
        signerDevice: null,
        descriptorKeys: [
          for (final key in parsed.descriptorKeys.where(
            (key) => key.xpub == signers[0].accountKey.xpub,
          ))
            key.copyWith(signerId: 'existing-local-signer'),
        ],
      ),
      WalletSigner(
        id: 'existing-hardware-signer',
        signer: SignerEntity.remote,
        signerDevice: null,
        descriptorKeys: [
          for (final key in parsed.descriptorKeys.where(
            (key) => key.xpub == signers[1].accountKey.xpub,
          ))
            key.copyWith(signerId: 'existing-hardware-signer'),
        ],
      ),
    ],
    scriptType: null,
    publicDescriptor: parsed.descriptor,
    balanceSat: BigInt.zero,
  );
}
