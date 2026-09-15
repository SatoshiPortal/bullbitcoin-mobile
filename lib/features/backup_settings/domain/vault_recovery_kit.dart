import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';

enum VaultRecoveryKitKind { mobile, cold, secondCold, inheritance }

/// The printable template deliberately has no mnemonic or passphrase fields.
/// Private material is written by hand on the completed paper kit.
final class VaultRecoveryKit {
  final BullVaultPolicy policy;
  final String walletId;
  final VaultRecoveryKitKind kind;
  final int wordCount;
  final String message;
  const VaultRecoveryKit({
    required this.policy,
    required this.walletId,
    required this.kind,
    required this.wordCount,
    required this.message,
  });

  bool get isValid =>
      const [12, 15, 18, 21, 24].contains(wordCount) &&
      walletId.isNotEmpty &&
      walletId.length <= 256 &&
      message.length <= 1200 &&
      (kind != VaultRecoveryKitKind.inheritance ||
          policy.inheritanceKey != null) &&
      (kind != VaultRecoveryKitKind.secondCold || policy.secondColdKey != null);
}

final class VaultRecoveryKitCopy {
  final String title;
  final String instructions;
  final String words;
  final String passphrase;
  final String dates;
  final String descriptor;
  final String joinLines;
  final String footer;
  final Map<int, String> schedule;
  const VaultRecoveryKitCopy({
    required this.title,
    required this.instructions,
    required this.words,
    required this.passphrase,
    required this.dates,
    required this.descriptor,
    required this.joinLines,
    required this.footer,
    required this.schedule,
  });
}
