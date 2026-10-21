import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class LoadLimitOrderCreationUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final DefaultWalletsFacade _defaultWalletsFacade;
  final GetWalletsUsecase _getWalletsUsecase;
  final LimitOrderRepository _repository;

  const LoadLimitOrderCreationUsecase(
    this._getExchangeUserSummaryUsecase,
    this._defaultWalletsFacade,
    this._getWalletsUsecase,
    this._repository,
  );

  @useResult
  Future<Result<LimitOrderCreationContext, LimitOrdersFailure>>
  execute() async {
    late final Result<DefaultWallets, LimitOrdersFailure> defaultWalletsResult;
    late final Result<UserSummary, LimitOrdersFailure> summaryResult;
    late final List<Wallet> appWallets;
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
    final rateResult = await _repository.getRate(selectedCurrency.code);
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
  _loadDefaultWallets() async {
    try {
      return Ok(await _defaultWalletsFacade.getDefaultWallets());
    } on Error {
      rethrow;
    } on ApiKeyException catch (e) {
      log.info('Exchange credential refused: ${e.runtimeType}');
      return Err(LimitOrdersAccountUnavailableFailure('$e'));
    } on ExchangeCredentialUnavailableException catch (e) {
      log.info('Exchange credential refused: ${e.runtimeType}');
      return Err(LimitOrdersAccountUnavailableFailure('$e'));
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the default wallets for a limit order',
        error: e,
        trace: st,
      );
      return Err(LimitOrdersUnexpectedFailure('$e'));
    }
  }

  Future<List<Wallet>> _loadAppWallets() async {
    try {
      switch (await _getWalletsUsecase.execute()) {
        case Ok(:final value):
          return value
              .where((w) => w.network.isBitcoin || w.network.isLiquid)
              .toList();
        // Same degrade as the catch below; the wallet repository already
        // logged the raw reason.
        case Err(:final failure):
          log.warning(
            'Failed to list wallets for a limit order: ${failure.runtimeType}',
          );
          return const [];
      }
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
