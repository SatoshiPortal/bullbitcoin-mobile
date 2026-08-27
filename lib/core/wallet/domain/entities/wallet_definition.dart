import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';

final class WalletDefinition {
  static const maxDescriptorLength = 10000;

  final String walletRef;
  final Network network;
  final String receiveDescriptor;
  final String? changeDescriptor;
  final String? masterFingerprint;
  final SignerDeviceEntity? signerDevice;
  final DateTime? birthday;
  final WalletProvenance provenance;
  final bool? seedPassphraseUsed;

  WalletDefinition({
    required String walletRef,
    required this.network,
    required String receiveDescriptor,
    String? changeDescriptor,
    String? masterFingerprint,
    this.signerDevice,
    this.birthday,
    required this.provenance,
    this.seedPassphraseUsed,
  }) : walletRef = walletRef.trim(),
       receiveDescriptor = receiveDescriptor.trim(),
       changeDescriptor = _optional(changeDescriptor),
       masterFingerprint = _fingerprint(masterFingerprint) {
    if (this.walletRef.isEmpty) {
      throw ArgumentError.value(walletRef, 'walletRef');
    }
    if (this.receiveDescriptor.isEmpty ||
        this.receiveDescriptor.length > maxDescriptorLength ||
        (this.changeDescriptor?.length ?? 0) > maxDescriptorLength) {
      throw ArgumentError('Wallet descriptors are invalid');
    }
  }

  bool hasSameDescriptors(WalletDefinition other) =>
      network == other.network &&
      receiveDescriptor == other.receiveDescriptor &&
      changeDescriptor == other.changeDescriptor;
}

enum WalletDefinitionRestoreStatus { created, alreadyPresent, conflict }

final class WalletDefinitionRestoreResult {
  final String walletRef;
  final WalletDefinitionRestoreStatus status;

  const WalletDefinitionRestoreResult({
    required this.walletRef,
    required this.status,
  });
}

String? _optional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _fingerprint(String? value) {
  final normalized = _optional(value)?.toLowerCase();
  if (normalized != null && !RegExp(r'^[0-9a-f]{8}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, 'masterFingerprint');
  }
  return normalized;
}
