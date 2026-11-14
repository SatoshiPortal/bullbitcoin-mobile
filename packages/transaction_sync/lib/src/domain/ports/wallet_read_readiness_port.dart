import 'package:primitives/primitives.dart';

import '../transaction_sync_failure.dart';
import '../public_wallet_descriptor.dart';
import '../wallet_revision.dart';

/// Writer-persisted proof for the exact generation/revision and SDK schema.
/// Liquid's path is relative to nativeWalletStoragePath, recorded by the writer
/// from the SDK-created store (network/enc_cache/hash), never caller input.
final class WalletReadReady {
  final WalletRevision revision;
  final int schemaVersion;
  final String? liquidCachePath;

  const WalletReadReady({
    required this.revision,
    required this.schemaVersion,
    this.liquidCachePath,
  });
}

/// Transitional injected contract until K/D publishes schema readiness.
/// Implement from durable writer metadata; absent/old initialization is Busy.
/// Success requires an active exact revision and attests that the catalog
/// supplied descriptor matches the initialized store; reject a mismatch.
/// No production fallback is provided. Liquid calls this while holding its lease.
abstract interface class WalletReadReadinessPort {
  Future<Result<WalletReadReady, TransactionSyncFailure>> check(
    PublicWalletDescriptor descriptor,
    WalletRevision expected,
    int requiredSchemaVersion,
  );
}
