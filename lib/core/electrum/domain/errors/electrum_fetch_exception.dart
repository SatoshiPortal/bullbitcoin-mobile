sealed class ElectrumFetchException implements Exception {
  final String message;

  ElectrumFetchException(this.message);

  @override
  String toString() => message;
}

class ElectrumNoServersException extends ElectrumFetchException {
  final String network;

  ElectrumNoServersException(this.network)
    : super('No Electrum servers available for network: $network');
}

class ElectrumFetchFailedException extends ElectrumFetchException {
  final String txid;
  final Object? cause;

  ElectrumFetchFailedException({required this.txid, this.cause})
    : super('Failed to fetch tx $txid from all servers: $cause');
}
