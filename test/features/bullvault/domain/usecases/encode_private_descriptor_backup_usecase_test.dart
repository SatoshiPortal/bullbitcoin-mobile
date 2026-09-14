import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_private_descriptor_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../bullvault_test_fixture.dart';

final class _FakeRepository extends Fake implements BullVaultRepository {
  final Map<String, BullVaultRecord> records = {};
  BullVaultFailure? readFailure;
  String? encodedDescriptor;

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String walletId,
  ) async => readFailure == null ? Ok(records[walletId]) : Err(readFailure!);

  @override
  Result<BullVaultDescriptorBackup, BullVaultFailure>
  encodePrivateDescriptorBackup({
    required String descriptor,
    required Network network,
  }) {
    encodedDescriptor = descriptor;
    return Ok(
      BullVaultDescriptorBackup(
        descriptor: descriptor,
        network: network,
        bytes: Uint8List.fromList([1, 2, 3]),
        recipients: const ['xpub-recipient'],
        lookupTokens: ['a' * 64],
      ),
    );
  }
}

void main() {
  late _FakeRepository repository;
  late EncodePrivateDescriptorBackupUsecase usecase;

  BullVaultRecord recordWith(BullVaultLifecycleStatus status) {
    final created = testBullVaultCreateResult(
      walletId: 'vault-wallet',
      status: status,
    );
    repository.records[created.record.walletId] = created.record;
    return created.record;
  }

  setUp(() {
    repository = _FakeRepository();
    usecase = EncodePrivateDescriptorBackupUsecase(repository);
  });

  test('encrypts the active vault descriptor exactly as stored', () async {
    final record = recordWith(BullVaultLifecycleStatus.active);
    final result = await usecase.execute('vault-wallet');
    expect(result, isA<Ok<BullVaultDescriptorBackup, BullVaultFailure>>());
    expect(
      repository.encodedDescriptor,
      record.recoveryPackage.policy.descriptor,
    );
  });

  test('a vault being renewed still has funds worth a backup', () async {
    recordWith(BullVaultLifecycleStatus.migrating);
    expect(
      await usecase.execute('vault-wallet'),
      isA<Ok<BullVaultDescriptorBackup, BullVaultFailure>>(),
    );
  });

  test('refuses a vault that never held funds, and an unknown one', () async {
    for (final status in [
      BullVaultLifecycleStatus.pending,
      BullVaultLifecycleStatus.cancelled,
    ]) {
      repository.records.clear();
      recordWith(status);
      expect(
        await usecase.execute('vault-wallet'),
        isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<BullVaultInvalidRecoveryFailure>(),
        ),
        reason: status.name,
      );
      expect(repository.encodedDescriptor, isNull);
    }
    repository.records.clear();
    expect(
      await usecase.execute('vault-wallet'),
      isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>(),
    );
  });

  test('a confirmed pending vault is backed up before activation', () async {
    final record = recordWith(BullVaultLifecycleStatus.pending);
    repository.records['vault-wallet'] = record.copyWith(
      recoveryPackageConfirmed: true,
    );

    expect(
      await usecase.execute('vault-wallet'),
      isA<Ok<BullVaultDescriptorBackup, BullVaultFailure>>(),
    );
  });

  test('a cancelled vault is refused however it was confirmed', () async {
    final record = recordWith(BullVaultLifecycleStatus.cancelled);
    repository.records['vault-wallet'] = record.copyWith(
      recoveryPackageConfirmed: true,
    );

    expect(
      await usecase.execute('vault-wallet'),
      isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>(),
    );
    expect(repository.encodedDescriptor, isNull);
  });

  test('a storage failure is reported, never treated as absence', () async {
    recordWith(BullVaultLifecycleStatus.active);
    repository.readFailure = const BullVaultBackupStatusFailure();
    expect(
      await usecase.execute('vault-wallet'),
      isA<Err<BullVaultDescriptorBackup, BullVaultFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<BullVaultBackupStatusFailure>(),
      ),
    );
    expect(repository.encodedDescriptor, isNull);
  });
}
