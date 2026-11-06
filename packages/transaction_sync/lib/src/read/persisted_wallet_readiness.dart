import 'package:primitives/primitives.dart';
import '../domain/transaction_sync_failure.dart';
import '../domain/wallet_catalog_port.dart';
import '../domain/wallet_revision.dart';
import '../write/revision_store.dart';
import '../write/store_identity.dart';
import 'wallet_read_readiness.dart';

/// Read-only verification of the proof committed by the writer, under admission.
final class PersistedWalletReadiness implements WalletReadReadiness {
  final RevisionStore _revisions;

  const PersistedWalletReadiness(this._revisions);

  @override
  Future<Result<WalletReadReady, TransactionSyncFailure>> check(
    PublicWalletDescriptor descriptor,
    WalletRevision expected,
    int requiredSchemaVersion,
  ) async {
    final record = _revisions.record(descriptor.key);
    if (record == null || record.state.lifecycle == WalletLifecycle.deleted) {
      return const Err(TransactionSyncNotFoundFailure());
    }
    if (record.intent != null ||
        record.state.stamp != expected ||
        record.state.initializedSchema != requiredSchemaVersion ||
        record.descriptorHash == null) {
      return const Err(TransactionSyncBusyFailure());
    }
    if (record.needsSync) return const Err(TransactionSyncNeedsRepairFailure());
    if (record.descriptorHash != descriptorDigest(descriptor)) {
      return const Err(TransactionSyncInvalidCatalogFailure());
    }
    if (descriptor is LiquidWalletDescriptor &&
        record.liquidCachePath == null) {
      return const Err(TransactionSyncBusyFailure());
    }
    return Ok(
      WalletReadReady(
        revision: expected,
        schemaVersion: record.state.initializedSchema,
        liquidCachePath: record.liquidCachePath,
      ),
    );
  }
}
