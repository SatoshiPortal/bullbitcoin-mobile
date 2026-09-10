import 'package:meta/meta.dart';

import 'recoverbull_network.dart';

@immutable
final class RecoverBullWallet {
  final String id;
  final String masterFingerprint;
  final RecoverBullNetwork network;
  final bool isPhysicalBackupTested;
  final DateTime? latestPhysicalBackup;

  const RecoverBullWallet({
    required this.id,
    required this.masterFingerprint,
    required this.network,
    required this.isPhysicalBackupTested,
    this.latestPhysicalBackup,
  });
}
