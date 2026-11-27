/// What the package hands back: the value types a caller names, and the
/// descriptor record from `crypto/` that appears in public signatures.
///
/// Explicit `show` lists, so what is public is decided here and nowhere
/// else — and so that `SecretMaterial`, the models and the keystore can
/// never reach a caller by accident.
library;

export 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, MnemonicLength;

export 'package:secrets/src/crypto/crypto.dart' show Descriptors;
export 'package:secrets/src/domain/domain.dart'
    show
        BackupRequiredFailure,
        BackupStateUnavailableFailure,
        BackupVerifierUnboundFailure,
        DatabaseKey,
        DatabaseKeyCorruptFailure,
        EncryptedVault,
        FetchSecretFailure,
        FingerprintMismatchFailure,
        InvalidMnemonicFailure,
        InvalidViewNameFailure,
        LastViewFailure,
        InvalidVaultFailure,
        VaultIdentityMismatchFailure,
        KeystoreLockedFailure,
        MnemonicRequiredFailure,
        SecretFailure,
        SecretInfo,
        SecretKind,
        SecretAlreadyExistsFailure,
        SecretNotFoundFailure,
        SharedWithOtherViewFailure,
        SecretOwnedByAnotherViewFailure,
        StoreSecretFailure,
        SwapMasterKey,
        TrashSecretFailure,
        UnsupportedNetworkFailure,
        UnreadableWalletFailure,
        UseSecretFailure,
        ViewId,
        ViewHoldsSecretsFailure,
        ViewInUseFailure,
        ViewNotOpenFailure,
        ViewSummary,
        VaultKey,
        WalletAlreadyRegisteredFailure,
        WalletRegistrationNotFoundFailure;
