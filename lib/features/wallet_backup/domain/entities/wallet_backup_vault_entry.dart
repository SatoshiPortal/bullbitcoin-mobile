import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// What the Keys screen holds about one vault signer beyond the descriptor:
/// which device it is, and the name it was registered under.
///
/// Keyed by the account key the vault's own policy already names, because a
/// restored wallet gives its signers new ids of its own.
final class WalletBackupVaultSigner {
  static const maxRegistrationNameLength = 50;

  final String accountXpub;
  final SignerDeviceEntity? signerDevice;
  final String? registrationName;

  WalletBackupVaultSigner({
    required String accountXpub,
    required this.signerDevice,
    String? registrationName,
  }) : accountXpub = accountXpub.trim(),
       registrationName = _optionalText(registrationName) {
    if (this.accountXpub.isEmpty ||
        (this.registrationName?.length ?? 0) > maxRegistrationNameLength) {
      throw ArgumentError('Invalid wallet backup vault signer');
    }
  }

  /// Whether this signer holds anything the descriptor does not already say.
  bool get isAnnotated => signerDevice != null || registrationName != null;
}

/// One BullVault in the backup: the recovery package the vault feature itself
/// emits, verbatim, plus the facts needed to place and replay it without
/// decoding it here.
///
/// Every record of a lineage is carried, whatever its lifecycle status, so
/// predecessor links and late-deposit monitoring survive recovery (D2).
final class WalletBackupVaultEntry {
  static const maxLabelLength = 50;
  static const maxPackageLength = 8 * 1024;
  static const maxSigners = 5;

  final String walletRef;
  final String? label;
  final String status;
  final Network network;
  final String lineageId;
  final int vaultGeneration;
  final String recoveryPackage;

  /// The signers that carry an annotation. A signer whose device and name are
  /// both unset says nothing the descriptor does not, so it is left out.
  final List<WalletBackupVaultSigner> signers;

  WalletBackupVaultEntry({
    required String walletRef,
    String? label,
    required String status,
    required this.network,
    required String lineageId,
    required this.vaultGeneration,
    required String recoveryPackage,
    Iterable<WalletBackupVaultSigner> signers = const [],
  }) : walletRef = walletRef.trim(),
       label = _optionalText(label),
       status = status.trim(),
       lineageId = lineageId.trim(),
       recoveryPackage = recoveryPackage.trim(),
       signers = List.unmodifiable(signers) {
    if (this.walletRef.isEmpty ||
        this.status.isEmpty ||
        this.lineageId.isEmpty ||
        vaultGeneration < 0 ||
        this.recoveryPackage.isEmpty ||
        this.recoveryPackage.length > maxPackageLength ||
        (this.label?.length ?? 0) > maxLabelLength ||
        this.signers.length > maxSigners ||
        this.signers.map((signer) => signer.accountXpub).toSet().length !=
            this.signers.length) {
      throw ArgumentError('Invalid wallet backup vault entry');
    }
  }

  /// Lineage first, then generation: a predecessor is replayed before the
  /// vault that links to it.
  static int compare(
    WalletBackupVaultEntry left,
    WalletBackupVaultEntry right,
  ) {
    final lineage = left.lineageId.compareTo(right.lineageId);
    if (lineage != 0) return lineage;
    final generation = left.vaultGeneration.compareTo(right.vaultGeneration);
    return generation != 0
        ? generation
        : left.walletRef.compareTo(right.walletRef);
  }
}

String? _optionalText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Reads the facts a recovery package states about itself, or null when the
/// package is not one the vault feature recognises.
typedef InspectVaultRecoveryPackage =
    WalletBackupVaultPackageFacts? Function(String recoveryPackage);

/// What a recovery package says about itself, read by the vault feature's own
/// codec so the backup never re-implements the package format.
final class WalletBackupVaultPackageFacts {
  final Network network;
  final String lineageId;
  final int vaultGeneration;
  final String descriptor;
  final int? birthHeight;

  const WalletBackupVaultPackageFacts({
    required this.network,
    required this.lineageId,
    required this.vaultGeneration,
    required this.descriptor,
    required this.birthHeight,
  });
}
