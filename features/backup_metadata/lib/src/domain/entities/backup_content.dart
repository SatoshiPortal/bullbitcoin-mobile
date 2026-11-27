import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';

/// A public descriptor without its checksum: the form in which two copies of
/// one descriptor are compared.
String canonicalDescriptor(String descriptor) =>
    descriptor.trim().split('#').first;

/// One public Bitcoin account, identified by its network and two public
/// descriptors. The wallet identifier of the machine that wrote it is not
/// part of the identity: restoring matches on this public material only.
final class BackupWallet {
  /// The identifier on the machine that holds this description. Only a hint to
  /// attribute records: a restore maps it to the local wallet the public
  /// descriptors match.
  final String walletId;
  final BitcoinNetwork network;
  final ScriptType scriptType;
  final String externalDescriptor;
  final String internalDescriptor;
  final String? label;
  final DateTime? birthday;
  final bool watchOnly;

  const BackupWallet({
    required this.walletId,
    required this.network,
    required this.scriptType,
    required this.externalDescriptor,
    required this.internalDescriptor,
    required this.watchOnly,
    this.label,
    this.birthday,
  });
}

/// One recorded BIP85 child: path, application, status and alias only. The
/// derived material is never part of a backup.
final class BackupDerivation {
  final String path;
  final String application;
  final String status;
  final String? alias;

  const BackupDerivation({
    required this.path,
    required this.application,
    required this.status,
    this.alias,
  });
}

/// Everything one group writes: labels and freezes, its public accounts and
/// its BIP85 registry.
final class BackupContent {
  final LabelsSnapshot labels;
  final List<BackupWallet> wallets;
  final List<BackupDerivation> derivations;

  /// Free-text fields left out because they looked like secret material. The
  /// count only: what they said is never kept.
  final int excluded;

  BackupContent({
    required this.labels,
    required List<BackupWallet> wallets,
    required List<BackupDerivation> derivations,
    this.excluded = 0,
  }) : wallets = List.unmodifiable(wallets),
       derivations = List.unmodifiable(derivations);
}
