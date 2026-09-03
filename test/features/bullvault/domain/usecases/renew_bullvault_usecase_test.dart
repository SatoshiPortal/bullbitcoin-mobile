import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_wallet_hidden_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/renew_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_renewal_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault_test_fixture.dart';
import '../../../../core_test/wallet/bdk_wallet_test_fixture.dart';

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockDeleteWalletUsecase extends Mock implements DeleteWalletUsecase {}

class _MockSetWalletHiddenUsecase extends Mock
    implements SetWalletHiddenUsecase {}

class _MockPrepareBullVaultTimeReferenceUsecase extends Mock
    implements PrepareBullVaultTimeReferenceUsecase {}

final class _RenewDescriptorPort implements BitcoinDescriptorPort {
  Wallet? importedWallet;
  int importCount = 0;

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
  }) => parseTestBullVaultDescriptor(
    descriptor: descriptor,
    network: network,
    keyIdPrefix: 'replacement-key',
    signerIdPrefix: 'unassigned',
  );

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
    importCount++;
    return importedWallet = Wallet(
      origin: 'replacement-wallet',
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

final class _RenewRepository implements BullVaultRepository {
  final Map<String, BullVaultRecord> records;
  BullVaultRecord? saved;
  BullVaultFailure? saveFailure;
  int generationSelectionCount = 0;
  final Set<int> releasedGenerations = {};

  _RenewRepository(BullVaultRecord current)
    : records = {current.walletId: current};

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
  }) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> linkRestoredRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord successor,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> cancelRenewal({
    required String previousWalletId,
    required String replacementWalletId,
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
  ) async {
    generationSelectionCount++;
    return const Ok(1);
  }

  @override
  Future<Result<void, BullVaultFailure>> releaseGeneration({
    required String lineageId,
    required int generation,
  }) async {
    releasedGenerations.add(generation);
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record) async {
    if (saveFailure case final failure?) return Err(failure);
    saved = record;
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
  final profiles = [
    (
      name: 'standard',
      protection: BullVaultProtection.standard,
      includesInheritance: false,
      hardwareEveryday: false,
      delayedMobileRecovery: true,
      schedule: BullVaultSchedule.defaultsFor(
        protection: BullVaultProtection.standard,
        includesInheritance: false,
        unit: BullVaultScheduleUnit.hours,
      ),
    ),
    (
      name: 'standard with inheritance',
      protection: BullVaultProtection.standard,
      includesInheritance: true,
      hardwareEveryday: false,
      delayedMobileRecovery: false,
      schedule: BullVaultSchedule.standardWithInheritance,
    ),
    (
      name: 'extra protection',
      protection: BullVaultProtection.extra,
      includesInheritance: false,
      hardwareEveryday: true,
      delayedMobileRecovery: false,
      schedule: BullVaultSchedule.extraWithoutInheritance,
    ),
    (
      name: 'extra protection with inheritance',
      protection: BullVaultProtection.extra,
      includesInheritance: true,
      hardwareEveryday: false,
      delayedMobileRecovery: false,
      schedule: BullVaultSchedule.extraWithInheritance,
    ),
  ];

  for (final profile in profiles) {
    test('renews the ${profile.name} signer configuration', () async {
      final fixture = _renewFixture(
        protection: profile.protection,
        includesInheritance: profile.includesInheritance,
        hardwareEveryday: profile.hardwareEveryday,
        delayedMobileRecovery: profile.delayedMobileRecovery,
        schedule: profile.schedule,
      );

      final result = await fixture.usecase.execute(
        BullVaultRenewRequest(
          walletId: fixture.currentWallet.id,
          label: 'Renewed BullVault',
          schedule: profile.schedule,
          timeReference: _timeReference(DateTime.utc(2028, 1, 15, 12)),
        ),
      );

      final replacement = switch (result) {
        Ok(:final value) => value.replacement,
        Err(:final failure) => throw TestFailure('$failure'),
      };
      expect(replacement.policy.protection, profile.protection);
      expect(
        replacement.policy.inheritanceKey != null,
        profile.includesInheritance,
      );
      expect(
        replacement.policy.secondColdKey != null,
        profile.protection.usesTwoColdKeys,
      );
      expect(
        replacement.policy.delayedMobileRecoveryKey != null,
        profile.delayedMobileRecovery,
      );
      expect(replacement.policy.schedule, same(profile.schedule));
      expect(
        replacement.policy.everydayKey.signer,
        profile.hardwareEveryday ? SignerEntity.remote : SignerEntity.local,
      );
    });
  }

  test(
    'serializes concurrent renewal and resumes its prepared successor',
    () async {
      final fixture = _renewFixture();
      final descriptorPort = fixture.descriptorPort;
      final currentWallet = fixture.currentWallet;
      final currentRecord = fixture.currentRecord;
      final repository = fixture.repository;
      final usecase = fixture.usecase;

      final results = await Future.wait([
        usecase.execute(
          BullVaultRenewRequest(
            walletId: currentWallet.id,
            label: 'BullVault generation 1',
            schedule: BullVaultSchedule.standardWithInheritance,
            timeReference: _timeReference(DateTime.utc(2028, 1, 15, 12)),
          ),
        ),
        usecase.execute(
          BullVaultRenewRequest(
            walletId: currentWallet.id,
            label: 'Ignored replacement label',
            schedule: BullVaultSchedule.standardWithInheritance,
            timeReference: _timeReference(DateTime.utc(2029, 1, 15, 12)),
          ),
        ),
      ]);

      final renewal = switch (results.first) {
        Ok(:final value) => value,
        Err(:final failure) => throw TestFailure('$failure'),
      };
      expect(renewal.replacement.policy.vaultGeneration, 1);
      expect(renewal.replacement.record.previousVaultId, currentWallet.id);
      expect(
        renewal.replacement.record.status,
        BullVaultLifecycleStatus.pending,
      );
      expect(renewal.replacement.wallet.isHidden, isTrue);
      expect(
        renewal.replacement.recoveryPackage.previousVaultId,
        currentWallet.id,
      );
      expect(repository.saved!.mobileAccount, currentRecord.mobileAccount);
      final resumed = results.last;

      expect(resumed, isA<Ok>());
      expect(
        (resumed as Ok).value.replacement.wallet.id,
        renewal.replacement.wallet.id,
      );
      expect(repository.generationSelectionCount, 1);
      expect(descriptorPort.importCount, 1);
    },
  );

  test(
    'deletes the imported wallet when renewal metadata cannot be saved',
    () async {
      final fixture = _renewFixture();
      fixture.repository.saveFailure = const BullVaultRenewalFailure();
      when(
        () => fixture.deleteWallet.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async {});

      final result = await fixture.usecase.execute(
        BullVaultRenewRequest(
          walletId: fixture.currentWallet.id,
          label: 'BullVault generation 1',
          schedule: BullVaultSchedule.standardWithInheritance,
          timeReference: _timeReference(DateTime.utc(2028, 1, 15, 12)),
        ),
      );

      expect(result, isA<Err<BullVaultRenewResult, BullVaultFailure>>());
      expect(fixture.repository.releasedGenerations, {1});
      verify(
        () => fixture.deleteWallet.execute(
          walletId: fixture.descriptorPort.importedWallet!.id,
        ),
      ).called(1);
    },
  );

  test('keeps the generation reserved when rollback fails', () async {
    final fixture = _renewFixture();
    fixture.repository.saveFailure = const BullVaultRenewalFailure();
    when(
      () => fixture.deleteWallet.execute(walletId: any(named: 'walletId')),
    ).thenThrow(Exception('wallet storage unavailable'));

    final result = await fixture.usecase.execute(
      BullVaultRenewRequest(
        walletId: fixture.currentWallet.id,
        label: 'BullVault generation 1',
        schedule: BullVaultSchedule.standardWithInheritance,
        timeReference: _timeReference(DateTime.utc(2028, 1, 15, 12)),
      ),
    );

    expect(result, isA<Err<BullVaultRenewResult, BullVaultFailure>>());
    expect(fixture.repository.releasedGenerations, isEmpty);
  });
}

final class _RenewFixture {
  final _RenewDescriptorPort descriptorPort;
  final _MockDeleteWalletUsecase deleteWallet;
  final Wallet currentWallet;
  final BullVaultRecord currentRecord;
  final _RenewRepository repository;
  final RenewBullVaultUsecase usecase;

  const _RenewFixture({
    required this.descriptorPort,
    required this.deleteWallet,
    required this.currentWallet,
    required this.currentRecord,
    required this.repository,
    required this.usecase,
  });
}

_RenewFixture _renewFixture({
  BullVaultProtection protection = BullVaultProtection.standard,
  bool includesInheritance = true,
  bool hardwareEveryday = false,
  bool delayedMobileRecovery = false,
  BullVaultSchedule? schedule,
}) {
  final descriptorPort = _RenewDescriptorPort();
  final getWallet = _MockGetWalletUsecase();
  final deleteWallet = _MockDeleteWalletUsecase();
  final setWalletHidden = _MockSetWalletHiddenUsecase();
  final reference = DateTime.utc(2027, 1, 15, 12);
  final everyday = _signer(
    BullVaultSignerRole.everyday,
    0,
    hardwareEveryday ? SignerDeviceEntity.ledgerNanoX : null,
    signer: hardwareEveryday ? SignerEntity.remote : SignerEntity.local,
    requiresPassphrase: delayedMobileRecovery,
  );
  final delayedMobile = delayedMobileRecovery
      ? _signer(
          BullVaultSignerRole.delayedMobileRecovery,
          3,
          null,
          signer: SignerEntity.local,
        )
      : null;
  final cold = _signer(
    BullVaultSignerRole.cold,
    1,
    SignerDeviceEntity.ledgerNanoX,
  );
  final secondCold = protection.usesTwoColdKeys
      ? _signer(BullVaultSignerRole.secondCold, 2, SignerDeviceEntity.bitbox02)
      : null;
  final inheritance = includesInheritance
      ? _signer(
          BullVaultSignerRole.inheritance,
          protection.usesTwoColdKeys ? 3 : 2,
          SignerDeviceEntity.krux,
        )
      : null;
  final resolvedSchedule =
      schedule ??
      BullVaultSchedule.defaultsFor(
        protection: protection,
        includesInheritance: includesInheritance,
      );
  final signers = [everyday, ?delayedMobile, cold, ?secondCold, ?inheritance];
  final currentDescriptor = BullVaultPolicy.descriptorTemplate(
    vaultGeneration: 0,
    network: Network.bitcoinTestnet,
    protection: protection,
    everydayKey: everyday.key,
    delayedMobileRecoveryKey: delayedMobile?.key,
    coldKey: cold.key,
    secondColdKey: secondCold?.key,
    inheritanceKey: inheritance?.key,
    schedule: resolvedSchedule,
    referenceTime: reference,
  );
  final currentPolicy = BullVaultPolicy.build(
    vaultGeneration: 0,
    network: Network.bitcoinTestnet,
    descriptor: currentDescriptor,
    protection: protection,
    everydayKey: everyday.key,
    delayedMobileRecoveryKey: delayedMobile?.key,
    coldKey: cold.key,
    secondColdKey: secondCold?.key,
    inheritanceKey: inheritance?.key,
    schedule: resolvedSchedule,
    timeReference: _timeReference(reference),
  );
  final currentWallet = Wallet(
    origin: 'current-wallet',
    label: 'BullVault',
    network: Network.bitcoinTestnet,
    signers: [for (final signer in signers) signer.walletSigner],
    scriptType: null,
    publicDescriptor: currentDescriptor,
    balanceSat: BigInt.zero,
  );
  final recovery = BullVaultRecoveryPackage(policy: currentPolicy);
  final currentRecord = BullVaultRecord(
    walletId: currentWallet.id,
    lineageId: currentPolicy.lineageId,
    vaultGeneration: 0,
    mobileAccount: hardwareEveryday ? null : 0,
    birthHeight: 3_000_000,
    recoveryPackage: recovery,
    createdAt: reference,
  );
  final repository = _RenewRepository(currentRecord);
  when(() => getWallet.execute(any())).thenAnswer((invocation) async {
    final walletId = invocation.positionalArguments.single as String;
    return walletId == currentWallet.id
        ? currentWallet
        : descriptorPort.importedWallet;
  });
  when(
    () => setWalletHidden.execute(
      walletId: any(named: 'walletId'),
      isHidden: any(named: 'isHidden'),
    ),
  ).thenAnswer((_) async {});
  final prepareTimeReference = _MockPrepareBullVaultTimeReferenceUsecase();
  when(
    () => prepareTimeReference.execute(isTestnet: true),
  ).thenAnswer((_) async => Ok(_timeReference(DateTime.utc(2028, 1, 15, 12))));
  final usecase = RenewBullVaultUsecase(
    repository,
    descriptorPort,
    getWallet,
    deleteWallet,
    ResumeBullVaultRenewalUsecase(repository, getWallet, setWalletHidden),
    prepareTimeReference,
  );
  return _RenewFixture(
    descriptorPort: descriptorPort,
    deleteWallet: deleteWallet,
    currentWallet: currentWallet,
    currentRecord: currentRecord,
    repository: repository,
    usecase: usecase,
  );
}

({BullVaultSignerKey key, WalletSigner walletSigner}) _signer(
  BullVaultSignerRole role,
  int mnemonicIndex,
  SignerDeviceEntity? device, {
  SignerEntity signer = SignerEntity.remote,
  bool requiresPassphrase = false,
}) {
  final derived = deriveSignerKeys(testMnemonics[mnemonicIndex]);
  final accountKey = WalletDescriptorKey(
    id: '${role.name}-account',
    signerId: role.name,
    masterFingerprint: derived.fingerprint,
    xpubFingerprint: derived.fingerprint,
    xpub: derived.xpub.split(']').last,
    derivationPath: "m/48'/1'/0'/2'",
    requiresPassphrase: requiresPassphrase,
  );
  final existingSignerId = 'existing-${role.name}';
  return (
    key: BullVaultSignerKey(
      role: role,
      accountKey: accountKey,
      signer: signer,
      signerDevice: device,
    ),
    walletSigner: WalletSigner(
      id: existingSignerId,
      signer: signer,
      signerDevice: device,
      descriptorKeys: [accountKey.copyWith(signerId: existingSignerId)],
    ),
  );
}

BullVaultTimeReference _timeReference(DateTime time) => BullVaultTimeReference(
  deviceTime: time,
  chainHeight: 3_000_000,
  medianTimePast:
      time.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
);
