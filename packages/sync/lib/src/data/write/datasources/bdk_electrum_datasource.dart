import 'package:rust_bindings/bdk.dart' as bdk;
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

  /// One pass over the wallet's own scripts at [externalIndices] and
  /// [internalIndices]: the server answers those histories only, never a
  /// transaction id. Nothing of the previous outputs is fetched, because a
  /// targeted pass reads the wallet's canonical transactions instead of
  /// rebuilding them.
  bdk.Update syncScriptIndices(
    bdk.Wallet wallet, {
    required List<int> externalIndices,
    required List<int> internalIndices,
    required int batchSize,
  }) {
    final builder = wallet.startSyncWithSpkIndices(
      externalIndices: externalIndices,
      internalIndices: internalIndices,
    );
    bdk.SyncRequest? request;
    try {
      request = builder.build();
      return _client.sync_(
        request: request,
        batchSize: batchSize,
        fetchPrevTxouts: false,
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
      _client.populateTxCache(txs: transactions);

  void populateAnchorCache(List<bdk.TxAnchor> anchors) =>
      _client.populateAnchorCache(anchors: anchors);

  /// Answered from the client's cache when a scan fetched previous outputs.
  bdk.Transaction fetchTx(bdk.Txid txid) => _client.fetchTx(txid: txid);

  void dispose() => _client.dispose();
}
