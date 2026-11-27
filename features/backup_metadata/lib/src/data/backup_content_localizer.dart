import 'package:labels/backup.dart';

import '../domain/entities/backup_content.dart';
import '../domain/entities/backup_inventory.dart';

/// Rewrites the wallet identifiers a backup carries into the identifiers of
/// this phone.
///
/// An identifier is only a hint of the machine that wrote the file; the
/// public descriptors are the identity. Each archived account is paired with
/// the local account of [group] whose two descriptors are equal (checksums
/// aside), and every record attributed to the archived identifier is moved to
/// the local one. A record whose account has no local counterpart keeps the
/// identifier it came with: the Labels owner then refuses it as not owned.
BackupContent localizeContent(BackupGroup group, BackupContent content) {
  (String, String) key(BackupWallet wallet) => (
    canonicalDescriptor(wallet.externalDescriptor),
    canonicalDescriptor(wallet.internalDescriptor),
  );
  final local = {for (final wallet in group.wallets) key(wallet): wallet};
  final renamed = <String, String>{};
  final wallets = <BackupWallet>[];
  for (final archived in content.wallets) {
    final match = local[key(archived)];
    if (match == null) {
      wallets.add(archived);
      continue;
    }
    renamed[archived.walletId] = match.walletId;
    wallets.add(
      BackupWallet(
        walletId: match.walletId,
        network: archived.network,
        scriptType: archived.scriptType,
        externalDescriptor: archived.externalDescriptor,
        internalDescriptor: archived.internalDescriptor,
        watchOnly: archived.watchOnly,
        label: archived.label,
        birthday: archived.birthday,
      ),
    );
  }
  final records = [
    for (final record in content.labels.records)
      if (renamed[record.walletId] case final id?)
        BackupLabelRecord(
          chain: record.chain,
          type: record.type,
          ref: record.ref,
          label: record.label,
          origin: record.origin,
          spendable: record.spendable,
          walletId: id,
        )
      else
        record,
  ];
  return BackupContent(
    labels: LabelsSnapshot(
      records: records,
      unattributedCount: content.labels.unattributedCount,
      skippedCount: content.labels.skippedCount,
    ),
    wallets: wallets,
    derivations: content.derivations,
    excluded: content.excluded,
  );
}
