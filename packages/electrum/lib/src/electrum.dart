import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show BitcoinTx;

import 'domain/electrum_failure.dart';
import 'domain/electrum_server_network.dart';
import 'domain/errors/electrum_fallback_exception.dart';
import 'domain/ports/electrum_servers_port.dart';
import 'domain/repositories/electrum_transaction_repository.dart';

/// Reads parsed Bitcoin transactions through the active server policy.
class Electrum {
  final ElectrumServersPort _serversPort;
  final ElectrumTransactionRepository _repository;

  const Electrum({required this._serversPort, required this._repository});

  @useResult
  Future<Result<BitcoinTx, ElectrumFailure>> fetchBitcoinTransaction({
    required String txid,
    required BitcoinNetwork network,
  }) async {
    final serverNetwork = switch (network) {
      BitcoinNetwork.mainnet => ElectrumServerNetwork.bitcoinMainnet,
      BitcoinNetwork.testnet => ElectrumServerNetwork.bitcoinTestnet,
      BitcoinNetwork.regtest => ElectrumServerNetwork.bitcoinRegtest,
      BitcoinNetwork.signet => null,
    };
    if (serverNetwork == null) {
      return const Err(ElectrumUnsupportedNetworkFailure());
    }
    try {
      return Ok(
        await _serversPort.runWithFallback(
          network: serverNetwork,
          operation: (connection) =>
              _repository.fetch(connection: connection, txid: txid),
        ),
      );
    } on NoElectrumServersConfiguredException catch (failure) {
      return Err(ElectrumNoTransactionServersFailure(failure.network));
    } on AllElectrumServersFailedException {
      return Err(ElectrumTransactionFetchFailure(txid));
    } on Exception catch (failure) {
      return Err(ElectrumUnexpectedFailure(failure.runtimeType.toString()));
    }
  }
}
