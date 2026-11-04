library;

export 'src/domain/wallet_storage_paths.dart'
    show WalletStoragePaths, WalletStoragePathsPort;

export 'src/domain/wallet.dart'
    show Wallet, $WalletCopyWith, Network, ScriptType;
export 'src/domain/signer_entity.dart' show SignerEntity;
export 'src/domain/signer_device_entity.dart' show SignerDeviceEntity, QrType;

export 'src/domain/wallet_balances.dart'
    show WalletBalances, $WalletBalancesCopyWith;
export 'src/domain/transaction_signature_status.dart'
    show TransactionSignatureStatus;
export 'src/domain/wallet_failure.dart'
    show
        WalletFailure,
        WalletTransactionLookupFailure,
        WalletStorageFailure,
        WalletNotFoundFailure,
        NoWalletsFoundFailure,
        WalletCannotDeleteDefaultFailure,
        WalletCannotDeleteWithOngoingSwapsFailure,
        WalletSyncFailure,
        WalletLwkStatusConflictFailure,
        WalletUnexpectedFailure;

export 'src/domain/wallet_error.dart'
    show
        WalletError,
        WalletNotFound,
        CannotDeleteDefaultWalletError,
        CannotDeleteWalletWithOngoingSwapsError,
        UnexpectedWalletError,
        WalletAlreadyExistsException;
export 'src/domain/manipulated_transaction_exception.dart'
    show ManipulatedTransactionException;
export 'src/domain/unverifiable_transaction_exception.dart'
    show UnverifiableTransactionException;
export 'src/domain/no_spendable_utxo_exception.dart'
    show NoSpendableUtxoException;
export 'src/domain/consolidation_required_exception.dart'
    show ConsolidationRequiredException;
export 'src/domain/insufficient_funds_exception.dart'
    show InsufficientFundsException;

export 'src/domain/wallet_origin_codec.dart' show WalletOriginCodec;

export 'src/domain/wallet_metadata.dart'
    show WalletMetadata, WalletMetadataExtension, $WalletMetadataCopyWith;
export 'src/domain/wallet_catalog_port.dart' show WalletCatalogPort;

export 'src/domain/wallet_freeze_store_port.dart' show WalletFreezeStorePort;

export 'src/domain/watch_only_wallet_import.dart' show WatchOnlyWalletImport;

export 'src/domain/wallet_account_derivation_port.dart'
    show WalletAccountDerivationPort, WalletAccountKeys;

export 'src/domain/network_bridge.dart' show NetworkBridge, ScriptTypeBridge;

// Composition and the held secrets adapters still construct these services.

export 'src/domain/wallet_connection_port.dart' show WalletConnectionPort;

export 'src/domain/wallet_coin_port.dart' show WalletCoinPort;

export 'src/domain/wallet_signing_port.dart' show WalletSigningPort;

export 'src/domain/bitcoin_send_port.dart' show BitcoinSendPort;

export 'src/domain/electrum_sync_result.dart' show ElectrumSyncResult;

export 'src/domain/wallet_sync_connection_port.dart'
    show WalletSyncConnectionPort;

export 'src/domain/wallet_coin.dart'
    show WalletCoin, BitcoinWalletCoin, LiquidWalletCoin;

export 'src/domain/wallet_address_key_chain.dart' show WalletAddressKeyChain;

export 'src/domain/wallet_utxo_repository.dart' show WalletUtxoRepository;

export 'src/domain/wallet_address_record.dart' show WalletAddressRecord;

export 'src/domain/wallet_address_reservation_port.dart'
    show WalletAddressReservationPort;

export 'src/domain/wallet_transaction_details.dart'
    show WalletTransactionDetails;
export 'src/domain/transaction_input_details.dart'
    show
        TransactionInputDetails,
        BitcoinTransactionInputDetails,
        LiquidTransactionInputDetails;
export 'src/domain/transaction_output_details.dart'
    show
        TransactionOutputDetails,
        BitcoinTransactionOutputDetails,
        LiquidTransactionOutputDetails;
