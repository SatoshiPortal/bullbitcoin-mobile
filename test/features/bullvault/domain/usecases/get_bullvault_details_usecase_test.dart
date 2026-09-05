import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../core_test/wallet/bdk_wallet_test_fixture.dart';

class _MockBullVaultRepository extends Mock implements BullVaultRepository {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetAddressAtIndexUsecase extends Mock
    implements GetAddressAtIndexUsecase {}

void main() {
  test('warns only while more than half of the first delay remains', () async {
    final repository = _MockBullVaultRepository();
    final getWallet = _MockGetWalletUsecase();
    final getAddress = _MockGetAddressAtIndexUsecase();
    final createdAt = DateTime.utc(2027, 1, 15, 12);
    final record = _record(createdAt);
    when(
      () => repository.getByWalletId(record.walletId),
    ).thenAnswer((_) async => Ok(record));
    when(
      () => repository.getLineage(record.lineageId),
    ).thenAnswer((_) async => Ok([record]));
    when(
      () => getAddress.execute(walletId: record.walletId, index: 0),
    ).thenAnswer((_) async => _address(record.walletId));

    final early = await GetBullVaultDetailsUsecase(
      repository,
      getWallet,
      getAddress,
      clock: () => DateTime.utc(2027, 7, 15, 12),
    ).execute(record.walletId);
    final late = await GetBullVaultDetailsUsecase(
      repository,
      getWallet,
      getAddress,
      clock: () => DateTime.utc(2028, 7, 15, 12),
    ).execute(record.walletId);

    expect(_details(early).showEarlyRenewalWarning, isTrue);
    expect(_details(late).showEarlyRenewalWarning, isFalse);
    verifyNever(() => getAddress.execute(walletId: record.walletId, index: 0));
  });

  test('resolves previous wallet details to the current vault', () async {
    final repository = _MockBullVaultRepository();
    final getWallet = _MockGetWalletUsecase();
    final getAddress = _MockGetAddressAtIndexUsecase();
    final createdAt = DateTime.utc(2027, 1, 15, 12);
    final previous = _record(
      createdAt,
      walletId: 'wallet-0',
      status: BullVaultLifecycleStatus.migrating,
    );
    final current = _record(
      createdAt.add(const Duration(days: 365)),
      walletId: 'wallet-1',
      generation: 1,
      lineageId: previous.lineageId,
      previousVaultId: previous.walletId,
    );
    when(
      () => repository.getByWalletId(current.walletId),
    ).thenAnswer((_) async => Ok(current));
    when(
      () => repository.getByWalletId(previous.walletId),
    ).thenAnswer((_) async => Ok(previous));
    when(
      () => repository.getLineage(current.lineageId),
    ).thenAnswer((_) async => Ok([previous, current]));
    when(
      () => getWallet.execute(previous.walletId),
    ).thenAnswer((_) async => _wallet(previous.walletId, balanceSat: 25));
    when(
      () => getAddress.execute(walletId: current.walletId, index: 0),
    ).thenAnswer((_) async => _address(current.walletId));

    final result = await GetBullVaultDetailsUsecase(
      repository,
      getWallet,
      getAddress,
      clock: () => DateTime.utc(2028, 7, 15, 12),
    ).execute(previous.walletId);
    final details = _details(result);

    expect(details.record.walletId, current.walletId);
    expect(details.policy.vaultGeneration, current.vaultGeneration);
    expect(details.migrationAddress, 'tb1qcurrent');
    expect(details.previousVaults.single.wallet.id, previous.walletId);
    expect(details.hasPreviousFunds, isTrue);
  });

  test('surfaces late funds sent to a cancelled replacement', () async {
    final repository = _MockBullVaultRepository();
    final getWallet = _MockGetWalletUsecase();
    final getAddress = _MockGetAddressAtIndexUsecase();
    final createdAt = DateTime.utc(2027, 1, 15, 12);
    final current = _record(createdAt);
    final cancelled = _record(
      createdAt.add(const Duration(days: 365)),
      walletId: 'wallet-1',
      generation: 1,
      lineageId: current.lineageId,
      previousVaultId: current.walletId,
      status: BullVaultLifecycleStatus.cancelled,
    );
    var cancelledBalance = 0;
    when(
      () => repository.getByWalletId(current.walletId),
    ).thenAnswer((_) async => Ok(current));
    when(
      () => repository.getLineage(current.lineageId),
    ).thenAnswer((_) async => Ok([current, cancelled]));
    when(() => getWallet.execute(cancelled.walletId)).thenAnswer(
      (_) async => _wallet(cancelled.walletId, balanceSat: cancelledBalance),
    );
    when(
      () => getAddress.execute(walletId: current.walletId, index: 0),
    ).thenAnswer((_) async => _address(current.walletId));
    final usecase = GetBullVaultDetailsUsecase(
      repository,
      getWallet,
      getAddress,
      clock: () => DateTime.utc(2028, 7, 15, 12),
    );

    final beforeDeposit = _details(await usecase.execute(current.walletId));
    cancelledBalance = 25;
    final afterDeposit = _details(await usecase.execute(current.walletId));

    expect(beforeDeposit.previousVaults, isEmpty);
    expect(afterDeposit.previousVaults.single.wallet.id, cancelled.walletId);
    expect(afterDeposit.hasPreviousFunds, isTrue);
  });
}

WalletAddress _address(String walletId) => WalletAddress(
  walletId: walletId,
  index: 0,
  address: 'tb1qcurrent',
  createdAt: DateTime.utc(2027),
  updatedAt: DateTime.utc(2027),
);

BullVaultRecord _record(
  DateTime createdAt, {
  String walletId = 'wallet-id',
  int generation = 0,
  String? lineageId,
  String? previousVaultId,
  BullVaultLifecycleStatus status = BullVaultLifecycleStatus.active,
}) {
  final everyday = _signer(BullVaultSignerRole.everyday, 0);
  final cold = _signer(BullVaultSignerRole.cold, 1);
  final policy = BullVaultPolicy.build(
    lineageId: lineageId,
    vaultGeneration: generation,
    network: Network.bitcoinTestnet,
    descriptor: 'tr(bullvault)',
    protection: BullVaultProtection.standard,
    everydayKey: everyday,
    coldKey: cold,
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
  return BullVaultRecord(
    walletId: walletId,
    lineageId: policy.lineageId,
    vaultGeneration: generation,
    mobileAccount: 0,
    mobileSeedFingerprint: everyday.accountKey.masterFingerprint,
    birthHeight: 3_000_000,
    recoveryPackage: BullVaultRecoveryPackage(
      previousVaultId: previousVaultId,
      policy: policy,
    ),
    previousVaultId: previousVaultId,
    status: status,
    createdAt: createdAt,
  );
}

Wallet _wallet(String walletId, {required int balanceSat}) => Wallet(
  origin: walletId,
  network: Network.bitcoinTestnet,
  signers: const [],
  scriptType: null,
  publicDescriptor: 'tr(bullvault)',
  balanceSat: BigInt.from(balanceSat),
  isHidden: true,
);

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
    signer: role == BullVaultSignerRole.everyday
        ? SignerEntity.local
        : SignerEntity.remote,
    signerDevice: null,
  );
}

BullVaultDetails _details(Result<BullVaultDetails?, BullVaultFailure> result) =>
    switch (result) {
      Ok(value: final details?) => details,
      Ok(value: null) => throw TestFailure('Missing BullVault details'),
      Err(:final failure) => throw TestFailure('$failure'),
    };
