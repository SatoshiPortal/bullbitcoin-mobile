import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:meta/meta.dart';

import '../../../domain/ports/wallet_connection_port.dart';

/// BDK requires an explicit transport; Liquid catalog URLs use LWK's host:port.
@visibleForTesting
String electrumClientUrl(String url) =>
    url.contains('://') ? url : 'ssl://$url';

/// One BDK Electrum client: requests and responses only, no wallet state.
final class BdkElectrumDatasource {
  final bdk.ElectrumClient _client;

  BdkElectrumDatasource(this._client);

  /// [direct] ignores the SOCKS route, for the Liquid protocol probe only.
  factory BdkElectrumDatasource.connect(
    WalletConnection connection, {
    bool direct = false,
  }) {
    bdk.ElectrumClient build() => bdk.ElectrumClient(
      url: electrumClientUrl(connection.url),
      socks5: !direct && connection.socks5?.isNotEmpty == true
          ? connection.socks5
          : null,
      timeout: connection.timeout.inSeconds.clamp(0, 255),
      retry: connection.retry.clamp(0, 255),
      validateDomain: connection.validateDomain,
    );
    try {
      return BdkElectrumDatasource(build());
    } on bdk.CouldNotCreateConnectionElectrumException catch (error) {
      if (error.errorMessage.contains('Failed to install CryptoProvider')) {
        return BdkElectrumDatasource(build());
      }
      rethrow;
    }
  }

  void ping() => _client.ping();

  bdk.Update syncRevealedScripts(bdk.Wallet wallet, {required int batchSize}) {
    final builder = wallet.startSyncWithRevealedSpks();
    bdk.SyncRequest? request;
    try {
      request = builder.build();
      return _client.sync_(
        request: request,
        batchSize: batchSize,
        fetchPrevTxouts: true,
      );
    } finally {
      request?.dispose();
      builder.dispose();
    }
  }

  bdk.Update fullScan(
    bdk.Wallet wallet, {
    required int stopGap,
    required int batchSize,
  }) {
    final builder = wallet.startFullScan();
    bdk.FullScanRequest? request;
    try {
      request = builder.build();
      return _client.fullScan(
        request: request,
        stopGap: stopGap,
        batchSize: batchSize,
        fetchPrevTxouts: true,
      );
    } finally {
      request?.dispose();
      builder.dispose();
    }
  }

  void populateTxCache(List<bdk.Transaction> transactions) =>
      _client.populateTxCache(transactions: transactions);

  void populateAnchorCache(List<bdk.TxAnchor> anchors) =>
      _client.populateAnchorCache(anchors: anchors);

  /// Answered from the client's cache when a scan fetched previous outputs.
  bdk.Transaction fetchTx(bdk.Txid txid) => _client.fetchTx(txid: txid);

  void dispose() => _client.dispose();
}
