import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/failures/pay_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class RefreshPayOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  RefreshPayOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<FiatPaymentOrder, PayFailure>> execute({
    required String orderId,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final repo = settings.environment.isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;

      return repo.refreshPayOrder(orderId);
    } catch (e, st) {
      log.severe(message: 'Failed to refresh pay order', error: e, trace: st);
      return Err(PayUnexpectedFailure(e.toString()));
    }
  }
}
