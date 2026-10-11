import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/verify_bullvault_descriptor_backup_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_initial_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../bullvault_test_fixture.dart';

class _Descriptors extends Fake implements BitcoinDescriptorPort {}

class _Records extends Fake implements BullVaultRepository {
  final records = <String, BullVaultRecord>{};
  bool activated = false;
  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String id,
  ) async => Ok(records[id]);
  @override
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record) async {
    records[record.walletId] = record;
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> activateInitial(
    BullVaultRecord record,
  ) async {
    activated = true;
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> activateRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord replacement,
  }) async {
    activated = true;
    return const Ok(null);
  }
}

class _Wallets extends Fake implements GetWalletUsecase {
  @override
  Future<Wallet?> execute(String id, {bool sync = false}) async =>
      testBullVaultCreateResult(walletId: id, usesBullMobile: false).wallet;
}

void main() {
  test('a checkbox alone cannot confirm descriptor backup', () async {
    final records = _Records();
    final record = testBullVaultCreateResult(usesBullMobile: false).record;
    records.records[record.walletId] = record;
    final result = await UpdateBullVaultSetupUsecase(
      records,
      _Wallets(),
      VerifyBullVaultDescriptorBackupUsecase(records, _Descriptors()),
    ).execute(walletId: record.walletId, recoveryPackageConfirmed: true);
    expect(result, isA<Err<BullVaultRecord, BullVaultFailure>>());
    expect(records.records[record.walletId]!.recoveryPackageConfirmed, isFalse);
  });
  test(
    'pending initial setup requires a local descriptor test receipt',
    () async {
      final records = _Records();
      final record = testBullVaultCreateResult(
        usesBullMobile: false,
      ).record.copyWith(recoveryPackageConfirmed: true);
      records.records[record.walletId] = record;
      final result = await ActivateInitialBullVaultUsecase(records, _Wallets())
          .execute(
            walletId: record.walletId,
            hardwareSetupDeferred: false,
            hasMobileBackup: true,
            mobileBackupDeferred: false,
          );
      expect(result, isA<Err<void, BullVaultFailure>>());
      expect(records.activated, isFalse);
    },
  );
  test(
    'pending renewal requires its own local descriptor test receipt',
    () async {
      final records = _Records();
      final previous = testBullVaultCreateResult(
        walletId: 'previous',
        status: .active,
        usesBullMobile: false,
      ).record;
      final next = testBullVaultCreateResult(
        walletId: 'next',
        previousVaultId: previous.walletId,
        lineageId: previous.lineageId,
        generation: 1,
        usesBullMobile: false,
      ).record.copyWith(recoveryPackageConfirmed: true);
      records.records.addAll({
        previous.walletId: previous,
        next.walletId: next,
      });
      final result = await ActivateBullVaultRenewalUsecase(records, _Wallets())
          .execute(
            previousWalletId: previous.walletId,
            replacementWalletId: next.walletId,
          );
      expect(result, isA<Err<void, BullVaultFailure>>());
      expect(records.activated, isFalse);
    },
  );
  test(
    'already active vaults stay usable without fabricating a test date',
    () async {
      final records = _Records();
      final record = testBullVaultCreateResult(
        status: .active,
        usesBullMobile: false,
      ).record.copyWith(recoveryPackageConfirmed: true);
      records.records[record.walletId] = record;
      expect(
        await ActivateInitialBullVaultUsecase(records, _Wallets()).execute(
          walletId: record.walletId,
          hardwareSetupDeferred: false,
          hasMobileBackup: true,
          mobileBackupDeferred: false,
        ),
        isA<Ok<void, BullVaultFailure>>(),
      );
      expect(records.records[record.walletId]!.descriptorTestedAt, isNull);
      expect(record.recoveryPackageVerified, isFalse);
      expect(records.activated, isFalse);
    },
  );
}
