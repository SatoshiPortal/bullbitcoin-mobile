import 'package:bull_sdk/bdk.dart' as bdk;

/// The native Electrum request path shared by both coordinated callers.
/// Callers retain their connection, cache and persistence failure boundaries.
bdk.Update fetchBdkElectrumUpdate({
  required bdk.Wallet wallet,
  required bdk.ElectrumClient client,
  required bool fullScan,
  required int stopGap,
  required int batchSize,
}) {
  if (fullScan) {
    final requestBuilder = wallet.startFullScan();
    try {
      final request = requestBuilder.build();
      try {
        return client.fullScan(
          request: request,
          stopGap: stopGap,
          batchSize: batchSize,
          fetchPrevTxouts: true,
        );
      } finally {
        request.dispose();
      }
    } finally {
      requestBuilder.dispose();
    }
  }
  final requestBuilder = wallet.startSyncWithRevealedSpks();
  try {
    final request = requestBuilder.build();
    try {
      return client.sync_(
        request: request,
        batchSize: batchSize,
        fetchPrevTxouts: true,
      );
    } finally {
      request.dispose();
    }
  } finally {
    requestBuilder.dispose();
  }
}
