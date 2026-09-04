import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';

final class WalletDefinition {
  static const maxDescriptorLength = 10000;

  final String walletRef;
  final Network network;
  final String descriptor;

  /// Every signer of the descriptor with its keys, in descriptor order. Empty
  /// for a definition that predates signer rosters; restore then derives one
  /// signer per key from [provenance].
  final List<WalletSigner> signers;
  final DateTime? birthday;
  final WalletProvenance provenance;

  WalletDefinition({
    required String walletRef,
    required this.network,
    required String descriptor,
    List<WalletSigner> signers = const [],
    this.birthday,
    required this.provenance,
  }) : walletRef = walletRef.trim(),
       descriptor = descriptor.trim(),
       signers = List.unmodifiable(signers) {
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

  /// The device of a single-signer definition; null for none or several.
  SignerDeviceEntity? get signerDevice =>
      signers.length == 1 ? signers.single.signerDevice : null;

  /// Whether any signer is a hardware or otherwise remote signer.
  bool get hasRemoteSigner =>
      signers.any((signer) => signer.signer == SignerEntity.remote);
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
