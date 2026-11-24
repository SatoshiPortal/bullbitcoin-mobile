import 'labels_snapshot.dart';

/// The current, authorized attribution for a metadata backup group.
final class LabelBackupScope {
  final String groupId;
  final Map<String, BackupLabelChain> wallets;
  final Set<String> allWallets;

  LabelBackupScope({
    required this.groupId,
    required Iterable<String> bitcoinWalletIds,
    required Iterable<String> liquidWalletIds,
    required Iterable<String> allWalletIds,
  }) : wallets = Map.unmodifiable({
         for (final id in bitcoinWalletIds) id: BackupLabelChain.bitcoin,
         for (final id in liquidWalletIds) id: BackupLabelChain.liquid,
       }),
       allWallets = Set.unmodifiable(allWalletIds);
}
