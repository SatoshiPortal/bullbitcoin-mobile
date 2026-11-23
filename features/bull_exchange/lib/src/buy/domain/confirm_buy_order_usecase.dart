import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/buy/domain/buy_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ConfirmBuyOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;

  ConfirmBuyOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<BuyOrder, BuyFailure>> execute({
    required String orderId,
  }) async {
    try {
      final SettingsEntity settings;
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(BuyUnexpectedFailure('Preferences read failed'));
      }
      final environment = settings.environment.networkEnv;
      final exchangeNetwork = switch (environment) {
        NetworkEnv.mainnet => BitcoinNetwork.mainnet,
        NetworkEnv.testnet => BitcoinNetwork.testnet,
        NetworkEnv.regtest => BitcoinNetwork.regtest,
        NetworkEnv.signet => BitcoinNetwork.signet,
      };
      if (!NetworkCapabilities.supports(
        exchangeNetwork,
        NetworkCapability.exchange,
      )) {
        log.warning('Capability refused feature=buy reason=unsupported');
        return const Err(BuyUnsupportedNetworkFailure());
      }
      final isTestnet = environment == NetworkEnv.testnet;
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      // Only the completion path may label wallet-owned transaction outputs.
      switch (await repo.confirmBuyOrder(orderId)) {
        case WriteDone(:final value):
          return Ok(value);
        case WriteRefused(:final reason):
          return Err(BuyUnexpectedFailure('confirm refused: $reason'));
        case WriteNotSent(reason: ExchangeNotSentReason.signedOut) ||
            WriteSessionRejected():
          log.warning('Cannot confirm the buy order: not authenticated');
          return const Err(BuyUnauthenticatedFailure());
        case WriteNotSent(:final reason):
          return Err(BuyUnexpectedFailure('confirm not sent: ${reason.name}'));
        case WriteOutcomeUnknown():
          // The request may have confirmed the order: the order says whether
          // it did, never a retry.
          return _confirmedAfterUnknownOutcome(repo, orderId);
      }
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to confirm the buy order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(BuyUnexpectedFailure(e.runtimeType.toString()));
    }
  }

  /// Re-reads the order after a confirm whose outcome is unknown. Ok when the
  /// order is confirmed; [BuyUnexpectedFailure] when it is still awaiting
  /// confirmation or ended unconfirmed, so Confirm can be offered again
  /// (API `orderSummary.ts`: a buy is "Awaiting confirmation" exactly while
  /// the user has not confirmed it); [BuyConfirmOutcomeUnknownFailure] when
  /// the order can't tell.
  Future<Result<BuyOrder, BuyFailure>> _confirmedAfterUnknownOutcome(
    ExchangeOrders repository,
    String orderId,
  ) async {
    final Order order;
    switch (await repository.getOrder(orderId)) {
      case Ok(:final value):
        order = value;
      case Err(:final failure):
        log.warning(
          'Could not re-read the buy order after an unknown confirmation: '
          '${failure.runtimeType}',
        );
        return const Err(BuyConfirmOutcomeUnknownFailure('re-read failed'));
    }
    if (order is! BuyOrder) {
      return const Err(BuyConfirmOutcomeUnknownFailure('order type'));
    }
    switch (order.orderStatus) {
      case OrderStatus.inProgress || OrderStatus.completed:
        log.warning(
          'Buy confirmation failed but the order is confirmed; reporting '
          'success',
        );
        return Ok(order);
      case OrderStatus.awaitingConfirmation ||
          OrderStatus.canceled ||
          OrderStatus.expired ||
          OrderStatus.orderExpired ||
          OrderStatus.rejected ||
          OrderStatus.failed:
        return Err(
          BuyUnexpectedFailure(
            'confirmation failed; order is ${order.orderStatus.name}',
          ),
        );
      case OrderStatus.unknown:
        return const Err(BuyConfirmOutcomeUnknownFailure('order status'));
    }
  }
}
