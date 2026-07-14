import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/data/datasources/btcpay_connection_datasource.dart';
import 'package:bb_mobile/features/btcpay/data/mappers/btcpay_connection_mapper.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/btcpay_connection_repository.dart';
import 'package:meta/meta.dart';

class BtcpayConnectionRepositoryImpl implements BtcpayConnectionRepository {
  final BtcpayConnectionDatasource _datasource;
  final BtcpayConnectionMapper _mapper = const BtcpayConnectionMapper();

  const BtcpayConnectionRepositoryImpl(this._datasource);

  @override
  @useResult
  Future<Result<BtcpayConnection?, BtcpayFailure>> getConnection(
    Environment environment,
  ) async {
    try {
      final model = await _datasource.get(environment.name);
      if (model == null) return const Ok(null);
      final connection = _mapper.toEntity(model);
      // A record stored under this environment's key must also claim that
      // environment; malformed or mismatched records are treated as absent.
      if (connection == null || connection.environment != environment) {
        return const Err(
          BtcpayStorageFailure('invalid stored connection record'),
        );
      }
      return Ok(connection);
    } on Exception catch (error, trace) {
      log.warning(
        'Could not load the BTCPay connection',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(BtcpayStorageFailure(error.runtimeType.toString()));
    }
  }

  @override
  @useResult
  Future<Result<void, BtcpayFailure>> saveConnection(
    BtcpayConnection connection,
  ) async {
    try {
      await _datasource.save(_mapper.toModel(connection));
      return const Ok(null);
    } on Exception catch (error, trace) {
      log.warning(
        'Could not save the BTCPay connection',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(BtcpayStorageFailure(error.runtimeType.toString()));
    }
  }
}
