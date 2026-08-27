import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';

final _remoteHashPattern = RegExp(r'^[0-9a-f]{64}$');

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
