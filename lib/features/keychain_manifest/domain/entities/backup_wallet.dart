import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';

/// Public wallet facts. Source signer annotations do not grant local ownership
/// on a recovering device; the existing importer must verify that separately.
final class BackupWallet {
  /// Reference within this backup, using the source owner's existing ID.
  /// Recovery maps it to the actual target ID instead of forcing identity reuse.
  final String reference;
  final Network network;
  final String publicDescriptor;
  final List<WalletSigner> signers;
  final bool isDefault;
  final bool isHidden;
  final String? label;
  final DateTime? birthday;

  BackupWallet({
    required this.reference,
    required this.network,
    required this.publicDescriptor,
    required List<WalletSigner> signers,
    required this.isDefault,
    required this.isHidden,
    this.label,
    this.birthday,
  }) : signers = List.unmodifiable(signers) {
    if (reference.isEmpty ||
        reference.length > 1024 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(reference) ||
        publicDescriptor.trim().isEmpty) {
      throw const FormatException(
        'Invalid public wallet reference or descriptor',
      );
    }
  }
}
