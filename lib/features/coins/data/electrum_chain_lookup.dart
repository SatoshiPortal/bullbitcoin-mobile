import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:proof_of_funds/proof_of_funds.dart';

/// Implements the `proof_of_funds` package's [ChainLookup] port over BULL's
/// Electrum layer, so a proof's claimed UTXOs can be checked against the live
/// UTXO set: it returns the real on-chain output (scriptPubKey + amount) and
/// whether the outpoint is currently unspent.
///
/// Server selection + fallback is delegated to [ElectrumServersPort] so the
/// custom-vs-default rule stays in one place (mirrors the transaction adapter).
class ElectrumChainLookup implements ChainLookup {
  const ElectrumChainLookup({
    required this.serversPort,
    required this.transactionRepository,
    required this.datasource,
    required this.isTestnet,
  });

  final ElectrumServersPort serversPort;
  final ElectrumTransactionRepository transactionRepository;
  final ElectrumRemoteDatasource datasource;
  final bool isTestnet;

  @override
  Future<ChainUtxo?> lookup(ProofOutpoint outpoint) async {
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: false,
    );

    try {
      return await serversPort.runWithFallback<ChainUtxo?>(
        network: network,
        operation: (server) async {
          // The funding transaction gives us the claimed output's real
          // scriptPubKey + amount.
          final tx = await transactionRepository.fetch(
            serverUrl: server.url,
            txid: outpoint.txId,
          );
          if (outpoint.vout < 0 || outpoint.vout >= tx.vout.length) {
            return null;
          }
          final out = tx.vout[outpoint.vout];
          final scriptPubKey = Uint8List.fromList(out.scriptPubKey.bytes);

          final unspent = await datasource.isOutpointUnspent(
            serverUrl: server.url,
            scriptPubkey: scriptPubKey,
            txid: outpoint.txId,
            vout: outpoint.vout,
          );

          return ChainUtxo(
            scriptPubKey: scriptPubKey,
            amountSat: out.value,
            unspent: unspent,
          );
        },
      );
    } catch (_) {
      // Any lookup failure (no servers, all failed, parse error) is reported
      // as "unknown" — verification treats a null lookup as mismatchOrMissing
      // and never as silently valid.
      return null;
    }
  }
}
