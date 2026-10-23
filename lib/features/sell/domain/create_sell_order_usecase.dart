import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class CreateSellOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;
  final PayjoinPolicyAccess _payjoinPolicy;

  CreateSellOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
    required this._payjoinPolicy,
  });

  /// [usePayjoin] is a request, not an instruction: it is resolved here against
  /// the global payjoin setting and the network, so a caller can pass the user's
  /// intent without also having to re-check the policy. The exchange applies its
  /// own pilot gate on top.
  @useResult
  Future<Result<Order, SellFailure>> execute({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    bool usePayjoin = false,
    RecipientSelection? recipient,
  }) async {
    if (recipient != null &&
        (currency != FiatCurrency.eur ||
            !const {
              RecipientType.sepaEur,
              RecipientType.confidentialSepaEur,
            }.contains(recipient.type))) {
      return const Err(SellUnexpectedFailure('Invalid EUR sell recipient'));
    }
    if (recipient?.requiresVirtualPayeeActivation ?? false) {
      return const Err(SellConfidentialSepaNotActivatedFailure());
    }
    try {
      final settings = await _settingsRepository.fetch();
      final payjoinEnabled = switch (await _payjoinPolicy.load()) {
        Ok(:final value) => value.sellEnabled,
        Err() => false,
      };
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final resolvedUsePayjoin =
          usePayjoin &&
          payjoinEnabled &&
          network == OrderBitcoinNetwork.bitcoin;
      log.fine(
        'Sell Payjoin order request: requested=$usePayjoin, '
        'sellEnabled=$payjoinEnabled, '
        'network=${network.value}, sent=$resolvedUsePayjoin',
      );
      final Order order;
      if (recipient == null) {
        order = await repo.placeSellOrder(
          orderAmount: orderAmount,
          currency: currency,
          network: network,
          usePayjoin: resolvedUsePayjoin,
        );
      } else {
        order = await repo.placeSellToRecipientOrderV2(
          orderAmount: orderAmount,
          recipientId: recipient.id,
          network: network,
          paymentProcessor: recipient.type == RecipientType.confidentialSepaEur
              ? SepaPaymentProcessor.confidential
              : SepaPaymentProcessor.regular,
          usePayjoin: resolvedUsePayjoin,
        );
      }
      log.fine(
        'Sell Payjoin order response: requested=$resolvedUsePayjoin, '
        'bip21Present=${order.payjoinBip21 != null}',
      );
      return Ok(order);
    } on BullBitcoinApiConfidentialSepaNotActivatedException {
      return const Err(SellConfidentialSepaNotActivatedFailure());
    } on ApiKeyException catch (e) {
      return Err(SellUnauthenticatedFailure(e.message));
    } on BullBitcoinApiMinAmountException catch (e) {
      return Err(
        SellBelowMinAmountFailure(
          minAmount: e.minAmount,
          currency: e.currency,
          logMessage: e.message,
        ),
      );
    } on BullBitcoinApiMaxAmountException catch (e) {
      return Err(
        SellAboveMaxAmountFailure(
          maxAmount: e.maxAmount,
          currency: e.currency,
          logMessage: e.message,
        ),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to place the sell order',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }
}
