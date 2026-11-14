/// The single owner of native wallet state. [Sync.openForeground] returns
/// [Sync], whose [Wallet] handles publish balances, coins, transactions and
/// addresses as [Observed] values; [Sync.openExisting] returns the narrow
/// [HeadlessSync] for background refreshes. Nothing here holds a native
/// handle; read.dart still lends them to the transaction builders.
library;

export 'src/public/sync.dart'
    show
        HeadlessSync,
        Sync,
        SyncChanges,
        SyncRecovery,
        Wallet,
        WalletAddressGroup,
        WalletOwnsGroup;
export 'src/domain/observed.dart';
export 'src/domain/wallet_values.dart';

export 'src/domain/wallet_key.dart';
export 'src/domain/sync_reason.dart';
export 'src/domain/sync_completion.dart';
export 'src/domain/bitcoin_spend.dart';
export 'src/data/bitcoin_transaction_id.dart';
export 'src/domain/sync_failure.dart';
export 'src/domain/wallet_revision.dart';
export 'src/domain/public_wallet_descriptor.dart';
export 'src/domain/repositories/wallet_writer_repository.dart';
export 'src/domain/ports/read_admission_port.dart';
export 'src/domain/ports/reserved_address_port.dart';
export 'src/domain/ports/wallet_catalog_port.dart';
export 'src/domain/ports/wallet_connection_port.dart';
export 'src/domain/ports/wallet_read_readiness_port.dart';
export 'src/domain/ports/wallet_revision_reader_port.dart';
export 'src/data/read/address_script.dart' show bitcoinAddressScript;
export 'src/domain/decoded_transactions.dart';
export 'src/data/codec/bitcoin_codec.dart'
    show
        bitcoinScriptAddress,
        canonicalBitcoinPsbt,
        decodeBitcoinPsbt,
        decodeBitcoinTransaction,
        finalizeBitcoinPsbts,
        maxBitcoinTransactionBytes,
        maxEncodedBitcoinPsbtLength,
        parseBitcoinAddress;
export 'src/data/codec/liquid_codec.dart'
    show
        decodeLiquidPset,
        decodeLiquidTransaction,
        liquidAddressNetwork,
        maxEncodedLiquidPsetLength,
        maxLiquidTransactionBytes;
export 'src/data/chain/electrum_chain.dart'
    show
        bitcoinTransactionKnown,
        broadcastBitcoinTransaction,
        broadcastLiquidTransaction,
        estimateBitcoinFees,
        probeBitcoinServer;
