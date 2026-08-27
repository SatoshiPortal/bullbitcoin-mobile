import 'dart:convert';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery_outcome.dart';

final class WalletBackupRecoveryOutcomeModel {
  final String status;
  final int completedAt;
  final int restoredCount;
  final int failedCount;

  const WalletBackupRecoveryOutcomeModel({
    required this.status,
    required this.completedAt,
    required this.restoredCount,
    required this.failedCount,
  });

  factory WalletBackupRecoveryOutcomeModel.fromDomain(
    WalletBackupRecoveryOutcome outcome,
  ) => WalletBackupRecoveryOutcomeModel(
    status: outcome.status.name,
    completedAt: outcome.completedAt,
    restoredCount: outcome.restoredCount,
    failedCount: outcome.failedCount,
  );

  WalletBackupRecoveryOutcome? toDomain() {
    final parsed = WalletBackupRecoveryStatus.values
        .where((value) => value.name == status)
        .firstOrNull;
    if (parsed == null ||
        completedAt < 0 ||
        restoredCount < 0 ||
        failedCount < 0) {
      return null;
    }
    return WalletBackupRecoveryOutcome(
      status: parsed,
      completedAt: completedAt,
      restoredCount: restoredCount,
      failedCount: failedCount,
    );
  }

  String encode() => jsonEncode({
    'status': status,
    'completedAt': completedAt,
    'restoredCount': restoredCount,
    'failedCount': failedCount,
  });

  static WalletBackupRecoveryOutcomeModel? tryDecode(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return null;
      return switch (decoded) {
        {
          'status': final String status,
          'completedAt': final int completedAt,
          'restoredCount': final int restoredCount,
          'failedCount': final int failedCount,
        } =>
          WalletBackupRecoveryOutcomeModel(
            status: status,
            completedAt: completedAt,
            restoredCount: restoredCount,
            failedCount: failedCount,
          ),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }
}
