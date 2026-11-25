import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';

/// One public Bitcoin account, identified by its network and two public
/// descriptors. The wallet identifier of the machine that wrote it is not
/// part of the identity: restoring matches on this public material only.
final class BackupWallet {
  final BitcoinNetwork network;
  final ScriptType scriptType;
  final String externalDescriptor;
  final String internalDescriptor;
  final String? label;
  final DateTime? birthday;
  final bool watchOnly;

  const BackupWallet({
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

  BackupContent({
    required this.labels,
    required List<BackupWallet> wallets,
    required List<BackupDerivation> derivations,
  }) : wallets = List.unmodifiable(wallets),
       derivations = List.unmodifiable(derivations);
}
