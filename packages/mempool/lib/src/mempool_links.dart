part of 'mempool.dart';

/// Explorer URLs for the selected server of a concrete network.
class MempoolLinks {
  final GetActiveMempoolServerUsecase _activeServer;

  const MempoolLinks._(this._activeServer);

  @useResult
  Future<Result<Uri, MempoolFailure>> transaction(
    String txid, {
    required Network network,
    String? fragment,
  }) {
    final details = network is BitcoinNetwork && fragment != null
        ? '?showDetails=true#$fragment'
        : '';
    return _link('tx/${Uri.encodeComponent(txid)}$details', network);
  }

  @useResult
  Future<Result<Uri, MempoolFailure>> address(
    String address, {
    required Network network,
  }) => _link('address/${Uri.encodeComponent(address)}', network);

  /// The wallet supplies the explorer-relative path and unblinding fragment.
  @useResult
  Future<Result<Uri, MempoolFailure>> unblindedTransaction(
    String path, {
    required LiquidNetwork network,
  }) => _link(path, network);

  Future<Result<Uri, MempoolFailure>> _link(
    String path,
    Network network,
  ) async {
    switch (await _activeServer.execute(network)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return _parseMempoolUri('${value.fullUrl}/$path');
    }
  }
}

Result<Uri, MempoolFailure> _parseMempoolUri(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.hasAuthority && uri.host.isNotEmpty
      ? Ok(uri)
      : const Err(MempoolInvalidUrlFailure());
}
