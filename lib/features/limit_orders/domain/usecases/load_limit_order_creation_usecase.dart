import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:preferences/preferences.dart' show ActiveEnvironmentReader;
import 'package:secrets/secrets.dart'
    show WalletInventory, UnreadableWalletFailure;
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';

import '../map_limit_order_failure.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class LoadLimitOrderCreationUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final Exchange _exchange;
  final WalletInventory _inventory;
  final ActiveEnvironmentReader _environment;
  final ExchangeLimitOrders _orders;

  const LoadLimitOrderCreationUsecase(
    this._getExchangeUserSummaryUsecase,
    this._exchange,
    this._inventory,
    this._environment,
    this._orders,
  );

  @useResult
  Future<Result<LimitOrderCreationContext, LimitOrdersFailure>>
  execute() async {
    late final Result<DefaultWallets, LimitOrdersFailure> defaultWalletsResult;
    late final Result<UserSummary, LimitOrdersFailure> summaryResult;
    late final List<LimitOrderAppWallet> appWallets;
    // Observe every parallel read before yielding.
    // Future.wait returns programmer errors to the caller.
    await Future.wait<void>([
      _loadDefaultWallets().then<void>((value) {
        defaultWalletsResult = value;
      }),
      _loadAppWallets().then<void>((value) {
        appWallets = value;
      }),
      _loadSummary().then<void>((value) {
        summaryResult = value;
      }),
    ]);

    final UserSummary summary;
    switch (summaryResult) {
      case Ok(:final value):
        summary = value;
      case Err(:final failure):
        return Err(failure);
    }

    final balances = summary.balances
        .where((balance) => balance.amount > 0)
        .map(
          (balance) => LimitOrderBalance(
            currency: FiatCurrency.fromCode(balance.currencyCode),
            amount: balance.amount,
          ),
        )
        .toList();
    if (balances.isEmpty) {
      return const Err(LimitOrdersNoFundedBalanceFailure('no funded balance'));
    }

    final preferredCurrency = FiatCurrency.tryFromCode(summary.currency ?? '');
    final selectedCurrency = balances
        .firstWhere(
          (balance) => balance.currency == preferredCurrency,
          orElse: () => balances.first,
        )
        .currency;

    final DefaultWallets defaultWallets;
    switch (defaultWalletsResult) {
      case Ok(:final value):
        defaultWallets = value;
      case Err(:final failure):
        return Err(failure);
    }

    final wallets = <LimitOrderWallet>[
      if (defaultWallets.bitcoinAddress.isNotEmpty)
        LimitOrderWallet(
          type: LimitOrderWalletType.bitcoin,
          address: defaultWallets.bitcoinAddress,
        ),
      if (defaultWallets.lightningAddress.isNotEmpty)
        LimitOrderWallet(
          type: LimitOrderWalletType.lightning,
          address: defaultWallets.lightningAddress,
        ),
      if (defaultWallets.liquidAddress.isNotEmpty)
        LimitOrderWallet(
          type: LimitOrderWalletType.liquid,
          address: defaultWallets.liquidAddress,
        ),
    ];

    // Do not start an unused rate request when a required input failed.
    final rateResult = (await _orders.getRate(selectedCurrency.code))
        .mapErr(mapLimitOrderFailure);
    return switch (rateResult) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => Ok(
        LimitOrderCreationContext(
          balances: balances,
          selectedCurrency: selectedCurrency,
          rate: value,
          wallets: wallets,
          appWallets: appWallets,
        ),
      ),
    };
  }

  Future<Result<UserSummary, LimitOrdersFailure>> _loadSummary() async {
    try {
      return Ok(await _getExchangeUserSummaryUsecase.execute());
    } on Error {
      rethrow;
    } on GetExchangeUserSummaryCredentialException catch (e) {
      log.info('Exchange account credential refused: ${e.runtimeType}');
      return Err(LimitOrdersAccountUnavailableFailure('$e'));
    } on GetExchangeUserSummaryException catch (e, st) {
      log.severe(
        message: 'Failed to load the account before creating a limit order',
        error: e,
        trace: st,
      );
      return Err(LimitOrdersAccountUnavailableFailure('$e'));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the account before creating a limit order',
        error: e,
        trace: st,
      );
      return Err(LimitOrdersUnexpectedFailure('$e'));
    }
  }

  Future<Result<DefaultWallets, LimitOrdersFailure>>
  _loadDefaultWallets() async => (await _exchange.getDefaultWallets()).mapErr(
    (failure) => switch (failure) {
      ExchangeNotAuthenticatedFailure() ||
      ExchangeSessionRejectedFailure() ||
      ExchangeApiKeyStorageFailure() ||
      ExchangeCredentialReadFailure() =>
        const LimitOrdersAccountUnavailableFailure(),
      _ => LimitOrdersUnexpectedFailure(failure.logMessage),
    },
  );

  Future<List<LimitOrderAppWallet>> _loadAppWallets() async {
    try {
      final environment = await _environment.readActiveEnvironment();
      final networks = switch (environment) {
        Ok(:final value) => <Network>[
          BitcoinNetwork.fromName(value.name),
          LiquidNetwork.fromName(value.name),
        ],
        Err() => null,
      };
      if (networks == null) return const [];
      final destinations = <LimitOrderAppWallet>[];
      for (final network in networks) {
        switch (await _inventory.walletsForNetwork(network)) {
          case Ok(:final value):
            destinations.addAll(
              value.wallets.map(
                (wallet) => LimitOrderAppWallet(
                  id: wallet.id,
                  label: wallet.label,
                  isLiquid: wallet.network is LiquidNetwork,
                ),
              ),
            );
          case Err(failure: UnreadableWalletFailure()):
            continue;
          case Err(:final failure):
            log.warning(
              'Failed to list wallets for a limit order: ${failure.runtimeType}',
            );
            return const [];
        }
      }
      return destinations;
    } on Error {
      rethrow;
    } catch (e, st) {
      log.warning(
        'Failed to list wallets for a limit order',
        error: e,
        trace: st,
      );
      return const [];
    }
  }
}
