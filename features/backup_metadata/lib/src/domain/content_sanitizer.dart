import 'package:labels/backup.dart';

import 'entities/backup_content.dart';
import 'secret_text_detector.dart';

/// Leaves out every free-text field that looks like secret material, and
/// counts what it left out.
///
/// - A record whose reference does goes entirely, a freeze included.
/// - A label record whose label or origin does; a freeze keeps its coin and
///   loses its text, because forgetting a freeze would be worse than a label.
/// - A wallet name or a BIP85 alias is blanked, never the whole entry: an
///   account must stay in the set of descriptors, and a child must stay in the
///   registry or its index could be allocated again.
///
/// Applied before anything is written and again to everything read back.
BackupContent sanitizeContent(BackupContent content) {
  var excluded = content.excluded;
  bool unsafe(String? value) => value != null && looksLikeSecretMaterial(value);

  final records = <BackupLabelRecord>[];
  for (final record in content.labels.records) {
    final unsafeRef = unsafe(record.ref);
    final unsafeLabel = unsafe(record.label);
    final unsafeOrigin = unsafe(record.origin);
    excluded +=
        (unsafeRef ? 1 : 0) + (unsafeLabel ? 1 : 0) + (unsafeOrigin ? 1 : 0);
    if (unsafeRef) {
      // The reference is what carries it and cannot be blanked: the whole
      // record goes, a freeze included.
      continue;
    }
    if (!unsafeLabel && !unsafeOrigin) {
      records.add(record);
      continue;
    }
    if (record.spendable != null) {
      records.add(
        BackupLabelRecord(
          chain: record.chain,
          type: record.type,
          ref: record.ref,
          spendable: record.spendable,
          walletId: record.walletId,
        ),
      );
    }
  }
  final wallets = [
    for (final wallet in content.wallets)
      if (unsafe(wallet.label))
        () {
          excluded++;
          return BackupWallet(
            walletId: wallet.walletId,
            network: wallet.network,
            scriptType: wallet.scriptType,
            externalDescriptor: wallet.externalDescriptor,
            internalDescriptor: wallet.internalDescriptor,
            watchOnly: wallet.watchOnly,
            birthday: wallet.birthday,
          );
        }()
      else
        wallet,
  ];
  final derivations = [
    for (final derivation in content.derivations)
      if (unsafe(derivation.alias))
        () {
          excluded++;
          return BackupDerivation(
            path: derivation.path,
            application: derivation.application,
            status: derivation.status,
          );
        }()
      else
        derivation,
  ];
  if (excluded == content.excluded) return content;
  return BackupContent(
    labels: LabelsSnapshot(
      records: records,
      unattributedCount: content.labels.unattributedCount,
      skippedCount: content.labels.skippedCount,
    ),
    wallets: wallets,
    derivations: derivations,
    excluded: excluded,
  );
}
