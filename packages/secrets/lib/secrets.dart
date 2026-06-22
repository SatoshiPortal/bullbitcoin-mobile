/// `secrets` — the sole owner of user secrets for the Bull wallet.
///
/// This barrel is the ENTIRE public surface. It intentionally never exports
/// `src/crypto/*`, the `SecretStorePort`/`SecureKeyValueStorePort` ports, the
/// `Mnemonic`/`Mnemonic` models, `MnemonicReader`, or any `*Impl` —
/// raw secret material has no path out of the package. Callers get non-secret
/// info, operation results, or sealed display widgets.
library;

// ── Contracts (interfaces only; impls stay internal) ──────────────────────
export 'src/domain/ports/seed_port.dart' show SeedPort;
export 'src/domain/ports/key_derivation_port.dart' show KeyDerivationPort;
export 'src/domain/ports/signer_port.dart' show SignerPort;
export 'src/domain/ports/swap_signer_port.dart' show SwapSignerPort;
export 'src/domain/ports/backup_vault_port.dart' show BackupVaultPort;
export 'src/domain/ports/bip85_port.dart' show Bip85Port;
export 'src/domain/ports/seed_index_port.dart' show SeedIndexPort; // app implements this

// ── Failures (all public-by-design; sealed, secret-free) ──────────────────
export 'src/domain/secrets_failure.dart'
    show
        SecretsFailure,
        SeedNotFoundFailure,
        KeychainLockedFailure,
        InvalidMnemonicFailure,
        DuplicateSeedFailure,
        NotAMnemonicSeedFailure,
        DerivationFailure,
        SigningFailure,
        VaultFailure,
        SecretsUnexpectedFailure;

// ── Value objects (non-secret, or secret-bearing with redacted toString) ──
export 'src/domain/value_objects/seed_info.dart' show SeedInfo;
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

// ── Sealed widgets (the ONLY Flutter exports) ─────────────────────────────
export 'src/ui/widgets/mnemonic_view.dart' show MnemonicView;
export 'src/ui/widgets/verify_backup_view.dart' show VerifyBackupView;
export 'src/ui/widgets/bip85_mnemonic_view.dart' show Bip85MnemonicView;
export 'src/ui/widgets/bip85_hex_view.dart' show Bip85HexView;

// ── DI ────────────────────────────────────────────────────────────────────
export 'locator.dart' show SecretsLocator;
