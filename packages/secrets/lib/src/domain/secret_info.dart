import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/passphrase_scope.dart';

enum SecretKind { mnemonic, bytes }

/// The only description of a stored secret that leaves this package.
///
/// Carries identity and shape, never material: safe to log, to put in a
/// bloc state, to pass through the widget tree, to compare. Operations
/// live on `Secret`, the handle `Secrets` hands out, and return
/// *derived* values — an xpub, a descriptor, a signature — not the
/// secret.
///
/// Building one costs no cryptography: the fingerprint is the storage
/// key, and everything else reads straight off the stored JSON. Only
/// [mnemonicFingerprint] can require a derivation, and only when a
/// passphrase is set.
@immutable
final class SecretInfo {
  /// Identity, and the join key against `WalletMetadata.masterFingerprint`.
  ///
  /// A [Fingerprint] rather than a bare string, so a wallet id or an
  /// xpub cannot be passed where an identity belongs — and so the value
  /// is validated on the way in: 8 lowercase hex characters, always.
  final Fingerprint id;

  final SecretKind kind;

  /// Identity this secret would have with an *empty* passphrase; `null`
  /// for a bytes secret. Equal to [id] when there is no passphrase.
  ///
  /// Use it to group secrets that share words but differ by passphrase,
  /// instead of reading the words out to compare them.
  final Fingerprint? mnemonicFingerprint;

  /// 12 or 24 in practice; `null` for a bytes secret.
  final int? wordCount;

  /// ⚠️ `true` does not mean every operation honours it. Liquid, the
  /// swap key and the vault derive from the words alone, silently. See
  /// doc/design.md, § Passphrase.
  final bool hasPassphrase;

  /// `null` for a mnemonic secret.
  final int? lengthInBits;

  const SecretInfo.mnemonic({
    required this.id,
    required this.mnemonicFingerprint,
    required this.wordCount,
    required this.hasPassphrase,
  }) : kind = SecretKind.mnemonic,
       lengthInBits = null;

  const SecretInfo.bytes({required this.id, required this.lengthInBits})
    : kind = SecretKind.bytes,
      mnemonicFingerprint = null,
      wordCount = null,
      hasPassphrase = false;

  bool get isMnemonic => kind == SecretKind.mnemonic;

  /// Tags a value that was derived from the BIP39 words alone.
  ///
  /// The one place the passphrase caveat is decided — the vault, the
  /// Liquid descriptor and a restore all go through here, so they cannot
  /// disagree. An invariant test holds it to that.
  PassphraseScope<T> scope<T>(T value) =>
      hasPassphrase ? WordsOnly(value) : WholeSecret(value);

  /// Identity only.
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
