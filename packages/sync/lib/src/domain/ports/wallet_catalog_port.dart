import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../public_wallet_descriptor.dart';
import '../sync_failure.dart';
import '../wallet_key.dart';

/// Supplies public wallet descriptors to Sync.
/// Each read must complete and must never call `Sync.close()`, which waits
/// for in-flight reads to finish.
abstract interface class WalletCatalogPort {
  @useResult
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list();
  @useResult
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(WalletKey key);
}
