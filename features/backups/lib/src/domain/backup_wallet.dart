import 'package:primitives/primitives.dart';

final class BackupWallet {
  final String id;
  final BitcoinNetwork network;
  final bool isDefault;
  final String? label;
  final Fingerprint? fingerprint;
  final DateTime? latestPhysicalBackup;

  const BackupWallet({
    required this.id,
    required this.network,
    required this.isDefault,
    required this.label,
    required this.fingerprint,
    this.latestPhysicalBackup,
  });
}
