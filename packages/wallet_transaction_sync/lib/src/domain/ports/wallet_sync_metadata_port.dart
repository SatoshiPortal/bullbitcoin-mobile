import '../wallet_network_key.dart';
import '../wallet_source_registration.dart';
import '../entities/wallet_sync_receipt.dart';

enum WalletDeletionPhase { markerWritten, snapshotEvicted, sourceDeleted }

class WalletSyncMetadata {
  final WalletSourceRegistration registration;
  final DateTime? lastAttemptedSyncAt;
  final DateTime? lastSuccessfulSyncAt;
  final String? contentFingerprint;
  final bool deletionPending;
  final WalletDeletionPhase? deletionPhase;
  const WalletSyncMetadata({
    required this.registration,
    this.lastAttemptedSyncAt,
    this.lastSuccessfulSyncAt,
    this.contentFingerprint,
    this.deletionPending = false,
    this.deletionPhase,
  });
}

abstract interface class WalletSyncMetadataPort {
  Future<WalletSyncMetadata?> read(WalletNetworkKey key);
  Future<void> writeRegistration(WalletSourceRegistration registration);
  Future<void> writeAttempt(WalletNetworkKey key, DateTime at);
  Future<void> recordLegacyForegroundSuccess(WalletNetworkKey key, DateTime at);
  Future<void> writeSuccessfulObservation(WalletSyncReceipt receipt);
  Future<DateTime?> readLastSuccessfulSyncAt(WalletNetworkKey key);
  Future<WalletSyncReceipt?> readReceipt(WalletNetworkKey key);
  Future<void> writeDeletionMarker(
    WalletNetworkKey key,
    WalletDeletionPhase phase,
  );
  Future<void> clear(WalletNetworkKey key);
}
