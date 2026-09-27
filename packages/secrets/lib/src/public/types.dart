/// What the package hands back: the value types a caller names, and the
/// descriptor record from `crypto/` that appears in public signatures.
///
/// Explicit `show` lists, so what is public is decided here and nowhere
/// else — and so that `SecretMaterial`, the models and the keystore can
/// never reach a caller by accident.
library;

export 'package:secrets/src/crypto/crypto.dart' show Descriptors;
export 'package:secrets/src/domain/domain.dart'
    show
        DatabaseKey,
        DatabaseKeyCorruptFailure,
        EncryptedVault,
        FetchSecretFailure,
        FingerprintMismatchFailure,
        InvalidMnemonicFailure,
        InvalidVaultFailure,
        KeystoreLockedFailure,
        MnemonicRequiredFailure,
        MnemonicWordCount,
        SecretFailure,
        SecretInfo,
        SecretKind,
        SecretAlreadyExistsFailure,
        SecretNotFoundFailure,
        StoreSecretFailure,
        SwapMasterKey,
        TrashSecretFailure,
        UnsupportedNetworkFailure,
        UseSecretFailure,
        VaultKey;
