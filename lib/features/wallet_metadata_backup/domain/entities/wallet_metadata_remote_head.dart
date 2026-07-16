import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';

final RegExp _remoteHashPattern = RegExp(r'^[0-9a-f]{64}$');

final class WalletMetadataRemoteHead {
  final int generation;
  final String etag;
  final WalletMetadataSnapshot snapshot;
  final String canonicalContentHash;

  WalletMetadataRemoteHead({
    required this.generation,
    required this.etag,
    required this.snapshot,
    required this.canonicalContentHash,
  }) {
    if (generation <= 0 ||
        !_remoteHashPattern.hasMatch(etag) ||
        !_remoteHashPattern.hasMatch(canonicalContentHash)) {
      throw ArgumentError('wallet metadata remote head is invalid');
    }
  }

  List<WalletMetadataRecord> get records => snapshot.records;
}

sealed class WalletMetadataRemoteFetchResult {
  const WalletMetadataRemoteFetchResult();
}

final class WalletMetadataRemoteAbsent extends WalletMetadataRemoteFetchResult {
  final int generation;
  final String? etag;

  const WalletMetadataRemoteAbsent({this.generation = 0, this.etag});
}

final class WalletMetadataRemotePresent
    extends WalletMetadataRemoteFetchResult {
  final WalletMetadataRemoteHead head;

  const WalletMetadataRemotePresent(this.head);
}

final class WalletMetadataRemoteUnsupported
    extends WalletMetadataRemoteFetchResult {
  final int generation;
  final String etag;
  final int envelopeVersion;

  const WalletMetadataRemoteUnsupported({
    required this.generation,
    required this.etag,
    required this.envelopeVersion,
  });
}

final class WalletMetadataRemoteStoreReceipt {
  final int generation;
  final String etag;

  const WalletMetadataRemoteStoreReceipt({
    required this.generation,
    required this.etag,
  });
}
