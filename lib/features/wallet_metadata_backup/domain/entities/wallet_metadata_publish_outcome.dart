enum WalletMetadataPublishStatus { notReady, initialEmpty, unchanged, stored }

final class WalletMetadataPublishOutcome {
  final WalletMetadataPublishStatus status;
  final int? remoteGeneration;
  final String? remoteEtag;

  const WalletMetadataPublishOutcome({
    required this.status,
    this.remoteGeneration,
    this.remoteEtag,
  });
}
