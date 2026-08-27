import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/btcpay_connection_repository.dart';
import 'package:meta/meta.dart';

class GetBtcpayConnectionUsecase {
  final GetSettingsUsecase _getSettings;
  final BtcpayConnectionRepository _connectionRepository;

  const GetBtcpayConnectionUsecase({
    required this._getSettings,
    required this._connectionRepository,
  });

  @useResult
  Future<Result<BtcpayConnection?, BtcpayFailure>> execute() async {
    try {
      final settings = await _getSettings.execute();
      return _connectionRepository.getConnection(settings.environment);
    } on Exception catch (error, trace) {
      log.warning(
        'Could not resolve the environment for BTCPay connection loading',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(BtcpayStorageFailure(error.runtimeType.toString()));
    }
  }
}
