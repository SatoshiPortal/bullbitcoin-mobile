import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_inspection.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

enum WalletBackupImportSituation {
  automaticBackupDisabled,
  serverUnavailable,
  noServerBackup,
  same,
  different,
}

enum WalletBackupImportSource { file, server }

enum WalletBackupDifference { inventory, metadata, vaults }

final class WalletBackupFileComparison {
  final WalletBackupFile file;
  final WalletBackupInspection? server;
  final WalletBackupFailure? serverFailure;
  final bool automaticBackupEnabled;
  final Set<WalletBackupDifference> differences;

  WalletBackupFileComparison({
    required this.file,
    required this.server,
    required this.automaticBackupEnabled,
    this.serverFailure,
    Set<WalletBackupDifference> differences = const {},
  }) : differences = Set.unmodifiable(differences) {
    if ((server == null) != (serverFailure != null) ||
        (server?.snapshot == null && differences.isNotEmpty)) {
      throw const FormatException('Inconsistent file comparison');
    }
  }

  WalletBackupImportSituation get situation => server == null
      ? WalletBackupImportSituation.serverUnavailable
      : !server!.head.found
      ? (automaticBackupEnabled
            ? WalletBackupImportSituation.noServerBackup
            : WalletBackupImportSituation.automaticBackupDisabled)
      : differences.isEmpty
      ? WalletBackupImportSituation.same
      : WalletBackupImportSituation.different;
}
