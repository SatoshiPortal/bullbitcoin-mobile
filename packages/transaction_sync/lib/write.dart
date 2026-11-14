/// Construction of the package's writer, reader and spend gate. The
/// foreground opens with [openForeground]; background code with
/// [openExisting], which never creates or migrates a store.
library;

export 'src/data/write/writer_stores.dart'
    show ForegroundStores, ExistingStores, openForeground, openExisting;
export 'src/data/datasources/revision_store_datasource.dart'
    show RevisionStoreUnavailable;
export 'src/data/native_store_paths.dart' show nativeWalletStoragePath;
export 'src/data/write/bitcoin_spend_gate.dart';
