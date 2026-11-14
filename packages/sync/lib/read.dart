/// Native reader hydration. The reader lends shared bdk/lwk wallet handles:
/// callers must not mutate, persist or dispose them.
library;

export 'src/data/read/wallet_snapshot_reader.dart'
    show WalletSnapshotReader, WalletReadSnapshot, WalletSnapshotException;

export 'src/data/read/validate_address.dart' show validateAddress;
