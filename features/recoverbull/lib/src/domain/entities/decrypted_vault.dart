// Public constructor names differ from private backing fields to preserve immutable views.
// ignore_for_file: prefer_initializing_formals

import 'dart:collection';

import 'package:dart_mappable/dart_mappable.dart';

part 'decrypted_vault.mapper.dart';

@MappableClass(
  generateMethods:
      GenerateMethods.decode | GenerateMethods.equals | GenerateMethods.copy,
)
final class DecryptedVault with DecryptedVaultMappable {
  final List<String> _mnemonic;
  final String masterFingerprint;
  final bool isEncryptedVaultTested;
  final bool isPhysicalBackupTested;
  final DateTime? latestEncryptedBackup;
  final DateTime? latestPhysicalBackup;

  const DecryptedVault({
    List<String> mnemonic = const [],
    // TODO(azad): masterFingerprint should be computed from mnemonic
    this.masterFingerprint = '',
    this.isEncryptedVaultTested = false,
    this.isPhysicalBackupTested = false,
    this.latestEncryptedBackup,
    this.latestPhysicalBackup,
  }) : _mnemonic = mnemonic;

  factory DecryptedVault.fromJson(Map<String, dynamic> json) =>
      DecryptedVaultMapper.fromMap(json);

  List<String> get mnemonic => UnmodifiableListView(_mnemonic);

  Map<String, dynamic> toJson() =>
      DecryptedVaultMapper.ensureInitialized().encodeMap<DecryptedVault>(this);

  @override
  String toString() => 'DecryptedVault(<redacted>)';
}
