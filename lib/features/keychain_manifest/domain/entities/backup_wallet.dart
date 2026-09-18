import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:crypto/crypto.dart';

/// Public wallet facts. Source signer annotations do not grant local ownership
/// on a recovering device; the existing importer must verify that separately.
final class BackupWallet {
  final Network network;
  final String publicDescriptor;
  final List<WalletSigner> signers;
  final bool isDefault;
  final bool isHidden;
  final String? label;
  final DateTime? birthday;

  BackupWallet({
    required this.network,
    required this.publicDescriptor,
    required List<WalletSigner> signers,
    required this.isDefault,
    required this.isHidden,
    this.label,
    this.birthday,
  }) : signers = List.unmodifiable(signers) {
    if (publicDescriptor.trim().isEmpty) {
      throw const FormatException('Missing wallet descriptor');
    }
  }

  String get reference => sha256
      .convert(
        utf8.encode(
          '${network.name}\u0000${publicDescriptor.split('#').first}',
        ),
      )
      .toString();
}
