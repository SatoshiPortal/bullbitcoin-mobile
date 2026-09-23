/// What the package hands back: the value types a caller names, and the
/// two aliases from `crypto/` that appear in public signatures.
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
        InvalidMnemonicFailure,
        InvalidVaultFailure,
        MnemonicRequiredFailure,
        MnemonicWordCount,
        PassphraseScope,
        SecretDeleteFailure,
        SecretDerivationFailure,
        SecretFailure,
        SecretFetchFailure,
        SecretIdentityMismatchFailure,
        SecretInfo,
        SecretKind,
        SecretListing,
        SecretNotFoundFailure,
        SecretStoreFailure,
        SecretStoreLockedFailure,
        SwapKey,
        WholeSecret,
        WordsOnly,
        UnsupportedNetworkFailure;
