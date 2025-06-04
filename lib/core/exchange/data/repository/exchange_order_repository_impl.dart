import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';

class ExchangeOrderRepositoryImpl implements ExchangeOrderRepository {
  // ignore: unused_field
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  // ignore: unused_field
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;

  ExchangeOrderRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource;
}
