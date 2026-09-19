import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class VerifyBullVaultDescriptorBackupUsecase {
  final BullVaultRepository _repository;
  final BitcoinDescriptorPort _descriptors;
  final DateTime Function() _clock;

  VerifyBullVaultDescriptorBackupUsecase(
    this._repository,
    this._descriptors, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @useResult
  Future<Result<DateTime, BullVaultFailure>> execute({
    required BullVaultRecord expected,
    required String source,
    BullVaultBackupTestKind kind = BullVaultBackupTestKind.descriptor,
  }) async {
    if (source.length > BullVaultRecoveryPackage.maximumFileBytes ||
        utf8.encode(source).length >
            BullVaultRecoveryPackage.maximumFileBytes) {
      return const Err(BullVaultBackupMismatchFailure());
    }
    var descriptor = source.trim();
    if (descriptor.isEmpty) return const Err(BullVaultBackupMismatchFailure());
    if (descriptor.startsWith('{')) {
      final decoded = _repository.decodeRecoveryPackage(descriptor);
      final current = _repository.decodeRecoveryPackage(
        _repository.encodeRecoveryPackage(expected.recoveryPackage),
      );
      switch ((decoded, current)) {
        case (Ok(value: final saved), Ok(value: final selected)):
          if (!selected.canBeEnrichedBy(saved) ||
              !saved.canBeEnrichedBy(selected)) {
            return const Err(BullVaultBackupMismatchFailure());
          }
          descriptor = saved.policy.descriptor;
        case _:
          return const Err(BullVaultBackupMismatchFailure());
      }
    }
    try {
      final network = expected.recoveryPackage.policy.network;
      final saved = _descriptors.parseBitcoinDescriptor(
        descriptor: descriptor,
        network: network,
      );
      final selected = _descriptors.parseBitcoinDescriptor(
        descriptor: expected.recoveryPackage.policy.descriptor,
        network: network,
      );
      if (saved.descriptor != selected.descriptor) {
        return const Err(BullVaultBackupMismatchFailure());
      }
    } on Exception {
      return const Err(BullVaultBackupMismatchFailure());
    }
    return _repository.recordBackupTest(
      expected: expected,
      kind: kind,
      testedAt: _clock().toUtc(),
    );
  }
}
