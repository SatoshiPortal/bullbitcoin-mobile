/// What the package speaks in: value types and the failure vocabulary.
///
/// No behaviour, no foreign dependency beyond `primitives` — the one
/// directory that needs no device to be verified, which the import
/// invariant test keeps true. The entry point for every other module;
/// nothing outside imports a file in here directly.
library;

export 'database_key.dart' show DatabaseKey;
export 'encrypted_vault.dart' show EncryptedVault;
export 'failures.dart';
export 'passphrase_scope.dart' show PassphraseScope, WholeSecret, WordsOnly;
export 'revealed_mnemonic.dart' show RevealedMnemonic, RevealReason;
export 'secret_info.dart' show SecretInfo, SecretKind;
export 'secret_material.dart'
    show MnemonicMaterial, SecretMaterial, SeedMaterial;
export 'swap_key.dart' show SwapKey;
