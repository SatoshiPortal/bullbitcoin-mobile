import 'dart:typed_data';

enum WalletBackupImportSituation {
  automaticBackupDisabled,
  serverUnavailable,
  noServerBackup,
  same,
  different,
}

enum WalletBackupImportSource { file, server }

enum WalletBackupDifference { walletManifest, externalWallets, protectedData }

final class WalletBackupSnapshotSummary {
  final int createdAt;
  final int walletCount;
  final int nostrIdentityCount;
  final int externalWalletCount;
  final int labelCount;
  final int frozenOutpointCount;
  final int walletPreferenceCount;

  const WalletBackupSnapshotSummary({
    required this.createdAt,
    required this.walletCount,
    required this.nostrIdentityCount,
    required this.externalWalletCount,
    required this.labelCount,
    required this.frozenOutpointCount,
    required this.walletPreferenceCount,
  });
}

final class WalletBackupImportComparison {
  final WalletBackupImportSituation situation;
  final WalletBackupSnapshotSummary file;
  final WalletBackupSnapshotSummary? server;
  final List<int>? _serverCiphertextBytes;
  final int? comparedServerGeneration;
  final String? comparedServerEtag;
  final Set<WalletBackupDifference> differences;

  WalletBackupImportComparison({
    required this.situation,
    required this.file,
    required this.server,
    Uint8List? serverCiphertextBytes,
    this.comparedServerGeneration,
    this.comparedServerEtag,
    required Set<WalletBackupDifference> differences,
  }) : _serverCiphertextBytes = serverCiphertextBytes == null
           ? null
           : List<int>.unmodifiable(serverCiphertextBytes),
       differences = Set.unmodifiable(differences) {
    if ((server == null) != (_serverCiphertextBytes == null)) {
      throw ArgumentError('Server summary and ciphertext must be paired');
    }
    if (comparedServerGeneration == null && comparedServerEtag != null) {
      throw ArgumentError('Server generation is required with an ETag');
    }
    if (server != null &&
        (comparedServerGeneration == null || comparedServerEtag == null)) {
      throw ArgumentError('Server snapshot requires its remote identity');
    }
  }

  Uint8List? copyServerCiphertextBytes() => _serverCiphertextBytes == null
      ? null
      : Uint8List.fromList(_serverCiphertextBytes);
}
