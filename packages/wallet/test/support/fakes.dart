import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

T okValue<T>(Result<T, WalletTransactionSyncFailure> result) =>
    (result as Ok<T, WalletTransactionSyncFailure>).value;

WalletTransactionSyncFailure errFailure<T>(
  Result<T, WalletTransactionSyncFailure> result,
) => (result as Err<T, WalletTransactionSyncFailure>).failure;

WalletTransactionSyncFailure? errFailureOrNull<T>(
  Result<T, WalletTransactionSyncFailure> result,
) => result is Err<T, WalletTransactionSyncFailure> ? result.failure : null;

class RecordingMetadata implements WalletSyncMetadataPort {
  final Map<WalletNetworkKey, WalletSyncMetadata> values = {};
  final Map<WalletNetworkKey, WalletSyncReceipt> receipts = {};
  bool failSuccess = false;
  bool failRead = false;
  int clearFailuresRemaining = 0;

  @override
  Future<WalletSyncMetadata?> read(WalletNetworkKey key) async {
    if (failRead) throw StateError('metadata store unavailable');
    return values[key];
  }

  @override
  Future<void> writeRegistration(WalletSourceRegistration registration) async {
    values.putIfAbsent(
      registration.key,
      () => WalletSyncMetadata(registration: registration),
    );
  }

  @override
  Future<void> writeAttempt(WalletNetworkKey key, DateTime at) async {}

  @override
  Future<void> recordLegacyForegroundSuccess(
    WalletNetworkKey key,
    DateTime at,
  ) async {}

  @override
  Future<void> writeSuccessfulObservation(WalletSyncReceipt receipt) async {
    if (failSuccess) throw StateError('metadata store unavailable');
    final old = values[receipt.key];
    if (old != null) {
      values[receipt.key] = WalletSyncMetadata(
        registration: old.registration,
        lastSuccessfulSyncAt: receipt.successfulAt,
        contentFingerprint: receipt.contentFingerprint,
      );
      receipts[receipt.key] = receipt;
    }
  }

  @override
  Future<WalletSyncReceipt?> readReceipt(WalletNetworkKey key) async =>
      receipts[key];

  @override
  Future<DateTime?> readLastSuccessfulSyncAt(WalletNetworkKey key) async =>
      values[key]?.lastSuccessfulSyncAt;

  @override
  Future<void> writeDeletionMarker(
    WalletNetworkKey key,
    WalletDeletionPhase phase,
  ) async {
    // Like the SQLite store, which only updates an existing row.
    final old = values[key];
    if (old == null) throw StateError('no metadata row to mark');
    values[key] = WalletSyncMetadata(
      registration: old.registration,
      lastAttemptedSyncAt: old.lastAttemptedSyncAt,
      lastSuccessfulSyncAt: old.lastSuccessfulSyncAt,
      contentFingerprint: old.contentFingerprint,
      deletionPending: true,
      deletionPhase: phase,
    );
  }

  @override
  Future<void> clear(WalletNetworkKey key) async {
    if (clearFailuresRemaining > 0) {
      clearFailuresRemaining--;
      throw StateError('metadata clear failed');
    }
    values.remove(key);
    receipts.remove(key);
  }
}
