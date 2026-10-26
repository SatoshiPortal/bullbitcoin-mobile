import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

enum SecretKind { mnemonic, seed }

/// The only description of a stored secret that leaves this package.
///
/// Carries fingerprint and shape, never material: safe to log, to put in a
/// bloc state, to pass through the widget tree, to compare. Operations
/// live on `Secret`, the handle `Secrets` hands out, and return
/// *derived* values — an xpub, a descriptor, a signature — not the
/// secret.
///
/// Building one costs no cryptography: the fingerprint is the storage
/// key, and everything else reads straight off the stored JSON.
@immutable
final class SecretInfo {
  /// Fingerprint, and the join key against `WalletMetadata.masterFingerprint`.
  ///
  /// A [Fingerprint] rather than a bare string, so a wallet id or an
  /// xpub cannot be passed where a fingerprint belongs — and so the value
  /// is validated on the way in: 8 lowercase hex characters, always.
  final Fingerprint id;

  final SecretKind kind;

  /// 12 or 24 in practice; `null` for a seed secret.
  final int? wordCount;

  /// ⚠️ `true` does not mean every operation honours it. Liquid and the
  /// vault derive from the words alone. See
  /// doc/design.md, § Passphrase.
  final bool hasPassphrase;

  /// `null` for a mnemonic secret.
  final int? lengthInBits;

  const SecretInfo.mnemonic({
    required this.id,
    required this.wordCount,
    required this.hasPassphrase,
  }) : kind = SecretKind.mnemonic,
       lengthInBits = null;

  const SecretInfo.seed({required this.id, required this.lengthInBits})
    : kind = SecretKind.seed,
      wordCount = null,
      hasPassphrase = false;

  bool get isMnemonic => kind == SecretKind.mnemonic;

  /// Fingerprint only.
  ///
  /// Two [SecretInfo] with the same [id] describe the same stored
  /// secret, so the remaining fields cannot differ without one of them
  /// being stale. Comparing them would make a stale copy look like a
  /// different secret, which is never what a caller means.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SecretInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SecretInfo(${id.hex}, ${kind.name}, '
      'words: $wordCount, passphrase: $hasPassphrase)';
}
