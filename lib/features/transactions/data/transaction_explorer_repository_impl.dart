import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_environment.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/transactions/data/explored_transaction_mapper.dart';
import 'package:bb_mobile/features/transactions/domain/entities/explored_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/repositories/transaction_explorer_repository.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart' show Err, Ok, Result;

String? bdkScriptAddress(List<int> scriptPubkey, Network network) {
  final bdkNetwork = switch (network) {
    Network.bitcoinMainnet => bdk.Network.bitcoin,
    Network.bitcoinTestnet => bdk.Network.testnet,
    Network.bitcoinRegtest => bdk.Network.regtest,
    Network.liquidMainnet ||
    Network.liquidTestnet ||
    Network.liquidRegtest => null,
  };
  if (bdkNetwork == null) return null;
  try {
    return bdk.Address.fromScript(
      script: bdk.Script(rawOutputScript: Uint8List.fromList(scriptPubkey)),
      network: bdkNetwork,
    ).toString();
  } catch (_) {
    return null;
  }
}

class TransactionExplorerRepositoryImpl
    implements TransactionExplorerRepository {
  final ElectrumServersPort _servers;
  final ElectrumTransactionRepository _electrumTransactions;
  final EnvironmentPort _environment;
  final ScriptAddressDecoder _decodeAddress;

  const TransactionExplorerRepositoryImpl({
    required this._servers,
    required this._electrumTransactions,
    required this._environment,
    this._decodeAddress = bdkScriptAddress,
  });

  @override
  Future<Result<ExploredTransaction, TransactionFailure>> fetch(
    String txid,
  ) async {
    try {
      final environment = await _environment.getEnvironment();
      final network = switch (environment) {
        ElectrumEnvironment.mainnet => Network.bitcoinMainnet,
        ElectrumEnvironment.testnet => Network.bitcoinTestnet,
        ElectrumEnvironment.regtest => Network.bitcoinRegtest,
      };
      final tx = await _servers.runWithFallback(
        network: ElectrumServerNetwork.fromEnvironment(
          environment: environment,
          isLiquid: false,
        ),
        operation: (connection) =>
            _electrumTransactions.fetch(connection: connection, txid: txid),
      );
      return Ok(
        ExploredTransactionMapper.fromBitcoinTx(
          tx,
          network: network,
          decodeAddress: _decodeAddress,
        ),
      );
    } catch (e) {
      log.warning('Transaction explorer: lookup failed (${e.runtimeType})');
      return Err(TransactionExplorerUnavailableFailure('${e.runtimeType}'));
    }
  }
}
