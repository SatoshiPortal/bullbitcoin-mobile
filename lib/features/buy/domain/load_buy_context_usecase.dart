import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class LoadBuyContextUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;

  const LoadBuyContextUsecase({
    required this._getExchangeUserSummaryUsecase,
    required this._getSettingsUsecase,
    required this._getWalletsUsecase,
    required this._getReceiveAddressUsecase,
    required this._getNetworkFeesUsecase,
    required this._convertSatsToCurrencyAmountUsecase,
  });

  /// The exchange account summary and the app settings, which the buy screen
  /// needs together before it can show anything.
  @useResult
  Future<
    Result<({UserSummary userSummary, SettingsEntity settings}), BuyFailure>
  >
  userSummaryAndSettings() async {
    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();
      final settings = await _getSettingsUsecase.execute();
      return Ok((userSummary: userSummary, settings: settings));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the exchange user summary or settings',
        error: e,
        trace: st,
      );
      return Err(BuyUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<List<Wallet>, BuyFailure>> wallets() async {
    try {
      return Ok(await _getWalletsUsecase.execute());
    } catch (e, st) {
      log.severe(message: 'Failed to load the wallets', error: e, trace: st);
      return Err(BuyUnexpectedFailure('$e'));
    }
  }

  /// The address the exchange will pay out to.
  @useResult
  Future<Result<WalletAddress, BuyFailure>> receiveAddress({
    required String walletId,
  }) async {
    try {
      return Ok(await _getReceiveAddressUsecase.execute(walletId: walletId));
    } catch (e, st) {
      log.severe(
        message: 'Failed to derive the buy payout address',
        error: e,
        trace: st,
      );
      return Err(BuyUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<FeeOptions, BuyFailure>> networkFees({
    required bool isLiquid,
  }) async {
    try {
      return Ok(await _getNetworkFeesUsecase.execute(isLiquid: isLiquid));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the network fees',
        error: e,
        trace: st,
      );
      return Err(BuyUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<double, BuyFailure>> satsToCurrency({
    BigInt? amountSat,
    String? currencyCode,
  }) async {
    try {
      return Ok(
        await _convertSatsToCurrencyAmountUsecase.execute(
          amountSat: amountSat,
          currencyCode: currencyCode,
        ),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to convert sats to the display currency',
        error: e,
        trace: st,
      );
      return Err(BuyUnexpectedFailure('$e'));
    }
  }
}
