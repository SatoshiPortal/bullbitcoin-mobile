/// Native wallet synchronization and contracts. No native handles escape.
library;

export 'src/domain/wallet_key.dart';
export 'src/domain/sync_reason.dart';
export 'src/domain/transaction_sync_failure.dart';
export 'src/domain/wallet_revision.dart';
export 'src/domain/wallet_connection_policy.dart';
export 'src/domain/reserved_address_port.dart';
export 'src/domain/wallet_catalog_port.dart';

export 'src/engine/electrum_sync.dart'
    show ElectrumSync, SyncCompletion, SyncFinished, SyncMode;
