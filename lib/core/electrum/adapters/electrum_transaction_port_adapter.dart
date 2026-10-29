import 'package:bb_mobile/core/wallet/data/cbf_privacy_guard.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/transactions/adapters/transaction_mapper.dart';
import 'package:bb_mobile/core/transactions/domain/domain_errors.dart';
import 'package:bb_mobile/core/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/transaction_port.dart';

/// Adapter implementing [TransactionPort] for the Electrum module.
///
/// Delegates server selection and fallback to [ElectrumServersPort.runWithFallback]
/// so the custom-vs-default rule lives in one place, then maps the parsed
/// [BitcoinTx] into a [Transaction] domain entity. Surfaces failures as
/// [TransactionPortError] so consumers never see electrum's error types.
class ElectrumTransactionPortAdapter implements TransactionPort {
  final ElectrumServersPort _serversPort;
  final ElectrumTransactionRepository _repository;
  final EnvironmentPort _environmentPort;
  final CbfPrivacyGuard? privacy;

  const ElectrumTransactionPortAdapter({
    required this._serversPort,
    required this._repository,
    required this._environmentPort,
    this.privacy,
  });

  @override
  Future<Transaction> fetch({required String txid, String? walletId}) async {
    final guard = privacy;
    if (guard != null) {
      return walletId == null
          ? guard.runUnattributedElectrum(() => _fetch(txid))
          : guard.runElectrum([walletId], () => _fetch(txid));
    }
    return _fetch(txid);
  }

  Future<Transaction> _fetch(String txid) async {
    final environment = await _environmentPort.getEnvironment();
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: environment.isTestnet,
      isLiquid: false,
    );

    try {
      return await _serversPort.runWithFallback(
        network: network,
        operation: (connection) async {
          final bitcoinTx = await _repository.fetch(
            connection: connection,
            txid: txid,
          );
          return TransactionMapper.fromBitcoinTx(
            bitcoinTx,
            isTestnet: environment.isTestnet,
          );
        },
      );
    } on NoElectrumServersConfiguredException {
      throw TransactionPortError.noServersAvailable(
        network: network.toString(),
      );
    } on AllElectrumServersFailedException catch (e) {
      throw TransactionPortError.fetchFailed(txid: txid, message: e.message);
    }
  }
}
