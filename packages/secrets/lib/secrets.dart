/// Stored mnemonics and raw seeds behind a custody boundary.
///
/// [Secrets] manages creation, import, lookup, listing, deletion, RecoverBull restoration, scoped database keys and application PIN operations. It returns [Secret] handles containing only metadata; [SecretEntry] also represents unreadable entries when listing.
///
/// Operations use the grouped API: `secret.derive`, `secret.sign`, `secret.backup`, `secret.verify` and `secret.widgets`. Implementations are internal; no public operation returns the stored words or seed. BIP85 children, the swap master key and the silent payment scan key are the documented derived-material outputs.
///
/// Bitcoin operations honour the mnemonic's passphrase. Liquid uses words alone. RecoverBull encrypts words only and returns its vault and key separately; restoring a passphrase-protected wallet requires that passphrase separately.
///
/// Result-returning methods expose typed [SecretFailure] values. See the README for a complete example and automatically maintained call trees, and `doc/design.md` for the custody contract.
library;

export 'src/public/extensions.dart'
    show
        SecretBackup,
        SecretBip85,
        SecretDerivation,
        SecretDescriptors,
        SecretExtension,
        SecretSigning,
        SecretVerification;
export 'src/public/secret.dart' show Secret, SecretEntry, UnreadableSecret;
export 'src/public/secrets.dart'
    show
        ApplicationStorage,
        AppUnlockCredential,
        DatabaseKeys,
        Recoverbull,
        RestoredVault,
        Secrets;
export 'src/public/types.dart';
export 'src/public/widgets.dart';
