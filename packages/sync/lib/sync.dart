/// The single owner of native wallet state. [Sync.foreground] returns
/// [Sync], whose [Wallet] handles publish balances, coins, history and
/// addresses as [Observed] values and build, check and broadcast spends;
/// [Sync.background] returns the narrow [BackgroundSync] for background
/// refreshes. Nothing here holds or lends a native handle: outside this
/// package, only `secrets` uses BDK and LWK. The codec and chain functions
/// work without a wallet.
library;

export 'src/public/sync.dart'
    show
        BackgroundRevision,
        BackgroundSync,
        Sync,
        SyncChanges,
        SyncCoins,
        SyncRecovery,
        Wallet,
        WalletAddressGroup,
        WalletCoinsGroup,
        WalletOwnsGroup,
        WalletTxGroup;
export 'src/domain/observed.dart';
export 'src/domain/wallet_values.dart';

export 'src/domain/wallet_key.dart';
export 'src/domain/sync_reason.dart';
export 'src/domain/sync_completion.dart';
export 'src/domain/sync_transaction_target.dart';
export 'src/domain/bitcoin_spend.dart';
export 'src/domain/spend.dart' hide signedForGeneration;
export 'src/data/bitcoin_transaction_id.dart';
export 'src/data/bitcoin_tx.dart';
export 'src/data/bitcoin_transaction_decoder.dart';
export 'src/domain/sync_failure.dart';
export 'src/domain/wallet_revision.dart';
export 'src/domain/public_wallet_descriptor.dart';
export 'src/domain/repositories/wallet_writer_repository.dart';
export 'src/domain/coin_freezes.dart';
export 'src/domain/ports/freeze_store_port.dart';
export 'src/domain/ports/input_reservation_port.dart';
export 'src/domain/ports/funding_reservation_port.dart';
export 'src/domain/ports/read_admission_port.dart';
export 'src/domain/ports/reserved_address_port.dart';
export 'src/domain/ports/wallet_catalog_port.dart';
export 'src/domain/ports/wallet_connection_port.dart';
export 'src/domain/ports/wallet_read_readiness_port.dart';
export 'src/domain/ports/wallet_revision_reader_port.dart';
export 'src/data/read/address_script.dart' show bitcoinAddressScript;
export 'src/data/read/validate_address.dart' show validateAddress;
export 'src/data/read/wallet_snapshot_reader.dart' show WalletSnapshotException;
export 'src/domain/decoded_transactions.dart';
export 'src/data/codec/bitcoin_psbt_facts.dart';
export 'src/data/codec/bitcoin_codec.dart'
    show
        bitcoinPsbtFee,
        bitcoinPsbtSkeleton,
        inspectBitcoinPsbt,
        bitcoinPublicDescriptor,
        bitcoinScriptAddress,
        canonicalBitcoinPsbt,
        finalizeBitcoinPsbts,
        parseBitcoinAddress;
export 'src/data/codec/liquid_codec.dart'
    show
        decodeLiquidPset,
        decodeLiquidTransaction,
        liquidAddressNetwork,
        liquidPsetFees,
        maxEncodedLiquidPsetLength,
        maxLiquidTransactionBytes;
export 'src/data/chain/electrum_chain.dart'
    show
        bitcoinTransactionKnown,
        broadcastBitcoinTransaction,
        broadcastBitcoinTransactionTo,
        broadcastLiquidTransaction,
        estimateBitcoinFees,
        liquidTransactionKnown,
        probeBitcoinServer;
export 'src/data/chain/bitcoin_prescan.dart' show prescanBitcoinWallet;
export 'src/data/write/datasources/native_store_errors.dart'
    show isLiquidStatusConflict;
export 'src/data/codec/bitcoin_recipient_amounts.dart'
    show bitcoinRecipientAmounts;
