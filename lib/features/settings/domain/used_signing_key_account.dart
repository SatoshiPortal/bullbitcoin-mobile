import 'package:bb_mobile/core/utils/bip48_derivation.dart';

final class UsedSigningKeyAccount {
  final int account;
  final String? walletId;
  final String? description;

  const UsedSigningKeyAccount({
    required this.account,
    this.walletId,
    this.description,
  });

  static int? accountFromOrigin(
    String? origin, {
    required String seedFingerprint,
    required int coinType,
  }) {
    final prefix = '[${seedFingerprint.toLowerCase()}/';
    if (origin == null ||
        !origin.toLowerCase().startsWith(prefix) ||
        !origin.endsWith(']')) {
      return null;
    }
    return Bip48Derivation.account(
      'm/${origin.substring(prefix.length, origin.length - 1)}',
      coinType: coinType,
    );
  }
}
