import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../sync_failure.dart';
import '../wallet_key.dart';
import '../wallet_revision.dart';

/// The writer implements persistence and reconciliation. Subscribe before reading;
/// re-read on resume/open since the stream covers only the current isolate.
abstract interface class WalletRevisionReaderPort {
  @useResult
  Future<Result<WalletRevisionState, SyncFailure>> read(WalletKey key);
  Stream<WalletRevisionState> watch(WalletKey key);
}
