import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/src/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_failure.dart';

import '../map_limit_order_failure.dart';
import '../../../exchange_payout_wallets.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class LoadLimitOrderCreationUsecase {
  final Exchange _exchange;
  final Preferences _preferences;
  final ExchangePayoutWallets _payouts;
  final ExchangeLimitOrders _orders;

  const LoadLimitOrderCreationUsecase(
    this._exchange,
    this._preferences,
    this._payouts,
    this._orders,
  );

  @useResult
  Future<Result<LimitOrderCreationContext, LimitOrdersFailure>>
  execute() async {
    final settings = await _preferences.fetch();
    final Environment environment;
    switch (settings) {
      case Ok(:final value):
        environment = value.environment;
      case Err():
        return const Err(LimitOrdersAccountUnavailableFailure());
    }
    final exchangeEnvironment = switch (environment) {
      Environment.mainnet => ExchangeEnvironment.mainnet,
      Environment.testnet => ExchangeEnvironment.testnet,
      Environment.regtest => null,
    };
    if (exchangeEnvironment == null) {
      return const Err(LimitOrdersUnsupportedNetworkFailure());
    }

    late final Result<DefaultWallets, LimitOrdersFailure> defaultWalletsResult;
    late final Result<UserSummary, LimitOrdersFailure> summaryResult;
    late final List<WalletRegistration> appWallets;
    // Observe every parallel read before yielding.
    // Future.wait returns programmer errors to the caller.
    await Future.wait<void>([
      _loadDefaultWallets().then<void>((value) {
        defaultWalletsResult = value;
      }),
      _loadAppWallets(environment).then<void>((value) {
        appWallets = value;
      }),
      _loadSummary(exchangeEnvironment).then<void>((value) {
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

  Future<Result<UserSummary, LimitOrdersFailure>> _loadSummary(
    ExchangeEnvironment environment,
  ) async {
    final result = await _exchange.getUserSummary(environment);
    return result.mapErr((failure) {
      switch (failure) {
        case ExchangeNotAuthenticatedFailure() ||
            ExchangeSessionRejectedFailure() ||
            ExchangeCredentialReadFailure() ||
            ExchangeApiKeyStorageFailure():
          break;
        default:
          log.severe(
            message: 'Failed to load the account before creating a limit order',
            error: failure.runtimeType,
            trace: StackTrace.current,
          );
      }
      return const LimitOrdersAccountUnavailableFailure();
    });
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

  Future<List<WalletRegistration>> _loadAppWallets(
    Environment environment,
  ) async {
    final wallets = <WalletRegistration>[];
    for (final network in <Network>[
      BitcoinNetwork.fromName(environment.name),
      LiquidNetwork.fromName(environment.name),
    ]) {
      switch (await _payouts.walletsForNetwork(network)) {
        case Ok(:final value):
          wallets.addAll(
            value.wallets.where((wallet) => wallet.network == network),
          );
        case Err(:final failure):
          log.warning(
            'Failed to list wallets for a limit order: ${failure.runtimeType}',
          );
      }
    }
    wallets.sort((left, right) => left.id.compareTo(right.id));
    return wallets;
  }
}
