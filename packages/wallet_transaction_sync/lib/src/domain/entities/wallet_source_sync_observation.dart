import 'wallet_source_observation.dart';

final class WalletSourceSyncObservation {
  final WalletSourceObservation observation;
  final Set<String> baselineTxids;

  WalletSourceSyncObservation({
    required this.observation,
    required Set<String> baselineTxids,
  }) : baselineTxids = Set.unmodifiable(baselineTxids);
}
