import 'package:bb_mobile/core/electrum/application/dtos/requests/get_electrum_servers_to_use_request.dart';
import 'package:bb_mobile/core/electrum/application/usecases/get_electrum_servers_to_use_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/transactions/adapters/transaction_mapper.dart';
import 'package:bb_mobile/core/transactions/application/transaction_port.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/error/transaction_error.dart';

/// Adapter implementing [TransactionPort] using the existing
/// [ElectrumRemoteDatasource] which fetches transactions via Electrum
/// with SQLite caching.
///
/// The Electrum server is resolved dynamically via
/// [GetElectrumServersToUseUsecase] so that the adapter always uses the
/// highest-priority server configured by the user.
class ElectrumTransactionAdapter implements TransactionPort {
  final GetElectrumServersToUseUsecase _getElectrumServersToUseUsecase;
  final SqliteDatabase _sqlite;

  ElectrumTransactionAdapter({
    required GetElectrumServersToUseUsecase getElectrumServersToUseUsecase,
    required SqliteDatabase sqlite,
  }) : _getElectrumServersToUseUsecase = getElectrumServersToUseUsecase,
       _sqlite = sqlite;

  @override
  Future<Transaction> fetch({required String txid}) async {
    final response = await _getElectrumServersToUseUsecase.execute(
      GetElectrumServersToUseRequest(
        network: ElectrumServerNetwork.bitcoinMainnet,
      ),
    );

    if (response.servers.isEmpty) {
      throw TransactionError.fetchFailed(
        txid: txid,
        message: 'No Electrum servers available',
      );
    }

    final serverDto = response.servers.first;

    final datasource = ElectrumRemoteDatasource(
      server: ElectrumServerModel(
        url: serverDto.url,
        network: serverDto.network,
      ),
      sqlite: _sqlite,
    );

    final model = await datasource.fetch(txid: txid);
    final entity = TransactionModelExtension.toEntity(model);
    return TransactionMapper.fromBitcoinTx(entity, isTestnet: false);
  }
}
