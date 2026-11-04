import 'package:path/path.dart' as path;

/// Resolves the existing installation's document directory in the host.
/// Native wallet code never chooses a platform-specific storage location.
abstract interface class WalletStoragePathsPort {
  Future<WalletStoragePaths> resolve(String walletId);
}

/// Paths are part of the persisted wallet format, independent of its backend.
final class WalletStoragePaths {
  final String bdkDatabase;
  final String lwkRoot;

  const WalletStoragePaths._({
    required this.bdkDatabase,
    required this.lwkRoot,
  });

  factory WalletStoragePaths.inDocuments({
    required String documentsDirectory,
    required String walletId,
  }) {
    if (documentsDirectory.isEmpty || walletId.isEmpty) {
      throw ArgumentError('A document directory and wallet ID are required');
    }
    // Preserve WalletModel.hexId's UTF-16 code-unit encoding, including for
    // non-ASCII IDs. UTF-8 bytes would select a different existing wallet.
    final hexId = walletId.codeUnits
        .map((unit) => unit.toRadixString(16).padLeft(2, '0'))
        .join();
    return WalletStoragePaths._(
      bdkDatabase: path.join(documentsDirectory, '${hexId}_bdk_dart'),
      lwkRoot: path.join(documentsDirectory, hexId),
    );
  }

  String get bdkParentsDatabase => '$bdkDatabase.parents.sqlite';
}
