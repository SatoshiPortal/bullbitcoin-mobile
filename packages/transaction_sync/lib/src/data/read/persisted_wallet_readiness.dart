import '../lease_diagnostics.dart';
import 'package:primitives/primitives.dart';
import '../../domain/transaction_sync_failure.dart';
import '../../domain/public_wallet_descriptor.dart';
import '../../domain/wallet_revision.dart';
import '../datasources/revision_store_datasource.dart';
import '../store_identity.dart';
import '../../domain/ports/wallet_read_readiness_port.dart';

/// Read-only verification of the proof committed by the writer, under admission.
final class PersistedWalletReadiness implements WalletReadReadinessPort {
  final RevisionStoreDatasource _revisions;

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
      LeaseDiagnostics.current?.busy(
        record.intent != null
            ? LeaseBusySource.lifecycleGate
            : record.state.stamp != expected
            ? LeaseBusySource.revisionRead
            : LeaseBusySource.schemaGate,
      );
      return const Err(TransactionSyncBusyFailure());
    }
    if (record.needsSync) return const Err(TransactionSyncNeedsRepairFailure());
    if (record.descriptorHash != descriptorDigest(descriptor)) {
      return const Err(TransactionSyncInvalidCatalogFailure());
    }
    if (descriptor is LiquidWalletDescriptor &&
        record.liquidCachePath == null) {
      LeaseDiagnostics.current?.busy(LeaseBusySource.schemaGate);
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
