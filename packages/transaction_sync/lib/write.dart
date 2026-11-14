/// Construction of the package's writer, reader and spend gate. The
/// foreground opens with [openForeground]; background code with
/// [openExisting], which never creates or migrates a store.
library;

export 'src/write/writer_stores.dart'
    show ForegroundStores, ExistingStores, openForeground, openExisting;
export 'src/write/revision_store_datasource.dart' show RevisionStoreUnavailable;
export 'src/write/native_store_paths.dart' show nativeWalletStoragePath;
export 'src/domain/bitcoin_spend.dart';
export 'src/write/bitcoin_spend_gate.dart';
export 'src/write/bitcoin_broadcast_id.dart';
