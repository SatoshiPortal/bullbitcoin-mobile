/// `secrets` — the sole owner of user secrets for the Bull wallet.
///
/// Consumed as a library: `import 'package:secrets/secrets.dart';`, call
/// [Secrets.init] once with the app's [SecretIndexPort], then create/operate via
/// [Secrets] statics and the sealed [Secret] handle. This barrel is the ENTIRE
/// public surface — it never exports `src/crypto/*`, the capability adapters/ports
/// (now internal), the `Mnemonic`/`Seed` models, `MnemonicReader`, or any `*Impl`.
/// Raw secret material has no path out: callers get non-secret info, operation
/// results, or sealed display widgets.
library;

// ── Public API: statics + the sealed Secret handle hierarchy ───────────────
export 'src/secrets_api.dart' show Secrets, Secret, MnemonicSecret, SeedSecret;

// ── The one injected contract (the APP implements this; everything else internal)
export 'src/domain/ports/secret_index_port.dart' show SecretIndexPort;

// ── Failures (returned in Result.Err; sealed, secret-free) ─────────────────
export 'src/domain/secrets_failure.dart'
    show
        SecretsFailure,
        SecretNotFoundFailure,
        KeychainLockedFailure,
        InvalidMnemonicFailure,
        DuplicateSecretFailure,
        NotAMnemonicFailure,
        DerivationFailure,
        SigningFailure,
        VaultFailure,
        SecretsUnexpectedFailure;

// ── Errors (THROWN precondition/programmer bugs — invalid value-object input) ─
export 'src/domain/secrets_error.dart'
    show
        SecretsError,
        InvalidXpubError,
        InvalidDescriptorError,
        InvalidPsbtError,
        InvalidBip85PathError,
        UnknownBip85ApplicationError,
        InvalidVaultKeyError,
        InvalidEncryptedVaultError,
        InvalidArkSecretError,
        UnsupportedMnemonicLengthError;

// ── Value objects (non-secret, or secret-bearing with redacted toString) ──
export 'src/domain/value_objects/secret_info.dart' show SecretInfo, SecretKind;
export 'src/domain/value_objects/mnemonic_language.dart' show MnemonicLanguage;
export 'src/domain/value_objects/mnemonic_length.dart' show MnemonicLength;
export 'src/domain/value_objects/descriptors.dart'
    show Xpub, BitcoinDescriptor, LiquidDescriptor;
export 'src/domain/value_objects/psbt.dart' show Psbt, SignedPsbt;
export 'src/domain/value_objects/bip85_types.dart'
    show Bip85Path, Bip85Application, Bip85Derivation, Bip85HexResult;
export 'src/domain/value_objects/backup.dart' show VaultKey, EncryptedVault;
export 'src/domain/value_objects/ark_secret.dart' show ArkSecret;
export 'src/domain/value_objects/signing_intent.dart'
    show
        SigningIntent,
        SendIntent,
        PayjoinIntent,
        SwapIntent,
        Output,
        SwapDirection,
        ChainDirection;
export 'src/domain/value_objects/created_swap.dart' show CreatedSwap;

// ── Sealed display widgets (the ONLY Flutter exports) ─────────────────────
export 'src/ui/widgets/secret_revealer.dart'
    show SecretRevealer, SecretRevealerStrings;
export 'src/ui/widgets/verify_backup_view.dart' show VerifyBackupView;
export 'src/ui/widgets/bip85_mnemonic_view.dart' show Bip85MnemonicView;
export 'src/ui/widgets/bip85_hex_view.dart' show Bip85HexView;

// ── Re-exported primitives used in the public signatures (single import) ──
export 'package:primitives/primitives.dart'
    show
        Fingerprint,
        BitcoinNetwork,
        LiquidNetwork,
        NetworkEnv,
        ScriptType,
        XpubType,
        Result,
        Ok,
        Err;
