import 'package:primitives/primitives.dart';

/// A backup-safe view of one admitted registration.
///
/// Only eligible Bitcoin wallets carry descriptors. Liquid wallet IDs are
/// included for label attribution but never carry confidential descriptors.
/// A watch-only wallet has no [secret]; it is identified by its public
/// descriptors alone.
final class MetadataBackupWallet {
  final String id;
  final Network? network;
  final Fingerprint? secret;
  final String? label;
  final bool isDefault;
  final bool isWatchOnly;
  final ScriptType? scriptType;
  final DateTime? birthday;
  final List<String> bitcoinPublicDescriptors;

  MetadataBackupWallet({
    required this.id,
    this.network,
    this.secret,
    this.label,
    this.isDefault = false,
    this.isWatchOnly = false,
    this.scriptType,
    this.birthday,
    List<String> bitcoinPublicDescriptors = const [],
  }) : bitcoinPublicDescriptors = List.unmodifiable(bitcoinPublicDescriptors);
}
