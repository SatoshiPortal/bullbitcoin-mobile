export 'package:primitives/primitives.dart'
    show BitcoinNetwork, Fingerprint, Result, Ok, Err;
export 'package:secrets/secrets.dart' show VaultKey;

export 'src/domain/entities/encrypted_vault.dart' show EncryptedVault;
export 'src/domain/entities/vault_backup.dart' show VaultBackup;
export 'src/domain/entities/vault_context.dart' show VaultContext;
export 'src/domain/entities/vault_recovery.dart'
    show VaultRecovery, VaultRecovered, VaultRecoveryNeedsWallets;
export 'src/domain/recoverbull_failure.dart'
    show
        RecoverBullFailure,
        RecoverBullUnexpectedFailure,
        KeyServerFailure,
        KeyServerFailureKind,
        VaultInvalidFailure,
        VaultSecretMissingFailure,
        VaultKeystoreLockedFailure,
        VaultStorageFailure,
        VaultUnsupportedSecretFailure,
        VaultContextChangedFailure,
        VaultWalletMissingFailure,
        VaultWalletMismatchFailure,
        VaultCancelledFailure;
export 'src/domain/recoverbull_wallet_port.dart' show RecoverBullWalletPort;
export 'src/public/recoverbull_facade.dart' show RecoverBullFacade;
export 'src/public/recoverbull_feature.dart' show RecoverBullFeature;
