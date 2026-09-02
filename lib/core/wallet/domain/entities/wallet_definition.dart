import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';

final class WalletDefinition {
  static const maxDescriptorLength = 10000;

  final String walletRef;
  final Network network;
  final String descriptor;
  final SignerDeviceEntity? signerDevice;
  final DateTime? birthday;
  final WalletProvenance provenance;

  WalletDefinition({
    required String walletRef,
    required this.network,
    required String descriptor,
    this.signerDevice,
    this.birthday,
    required this.provenance,
  }) : walletRef = walletRef.trim(),
       descriptor = descriptor.trim() {
    if (this.walletRef.isEmpty) {
      throw ArgumentError.value(walletRef, 'walletRef');
    }
    if (this.descriptor.isEmpty ||
        this.descriptor.length > maxDescriptorLength) {
      throw ArgumentError('Wallet descriptor is invalid');
    }
  }

  bool hasSameDescriptor(WalletDefinition other) =>
      network == other.network && descriptor == other.descriptor;
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
