import 'labels_snapshot.dart';

/// The current, authorized attribution for a metadata backup group.
final class LabelBackupScope {
  final String groupId;
  final Map<String, BackupLabelChain> wallets;
  final Set<String> allWallets;

  /// Whether the caller still authorizes this operation. Labels owns no
  /// notion of session: the caller hands in a check, asked at the start of an
  /// apply, inside its transaction just before the commit (a false answer
  /// rolls everything back) and before each freeze. Freezes already applied
  /// stay; the rest are reported as not applied.
  final bool Function() authority;

  LabelBackupScope({
    required this.groupId,
    required Iterable<String> bitcoinWalletIds,
    required Iterable<String> liquidWalletIds,
    required Iterable<String> allWalletIds,
    this.authority = _always,
  }) : wallets = Map.unmodifiable({
         for (final id in bitcoinWalletIds) id: BackupLabelChain.bitcoin,
         for (final id in liquidWalletIds) id: BackupLabelChain.liquid,
       }),
       allWallets = Set.unmodifiable(allWalletIds);
}

bool _always() => true;
