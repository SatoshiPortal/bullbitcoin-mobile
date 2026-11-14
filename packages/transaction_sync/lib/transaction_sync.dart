/// Native wallet synchronization and contracts. No native handles escape.
library;

export 'src/domain/wallet_key.dart';
export 'src/domain/sync_reason.dart';
export 'src/domain/sync_completion.dart';
export 'src/domain/transaction_sync_failure.dart';
export 'src/domain/wallet_revision.dart';
export 'src/domain/public_wallet_descriptor.dart';
export 'src/domain/repositories/wallet_writer_repository.dart';
export 'src/domain/ports/read_admission_port.dart';
export 'src/domain/ports/reserved_address_port.dart';
export 'src/domain/ports/wallet_catalog_port.dart';
export 'src/domain/ports/wallet_connection_port.dart';
export 'src/domain/ports/wallet_read_readiness_port.dart';
export 'src/domain/ports/wallet_revision_reader_port.dart';

export 'src/data/write/sync/electrum_sync.dart' show ElectrumSync;
