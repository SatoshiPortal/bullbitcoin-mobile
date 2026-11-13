import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';

enum BuyEntry { allowed, signIn, unavailable }

class GetBuyEntryUsecase {
  const GetBuyEntryUsecase(this._exchange);
  final ExchangeFacade _exchange;

  Future<Result<BuyEntry, BuyFailure>> execute({required bool isIOS}) async {
    final result = await _exchange.tradingEntry(isIOS: isIOS);
    return result
        .map(
          (entry) => switch (entry) {
            ExchangeTradingEntry.allowed => BuyEntry.allowed,
            ExchangeTradingEntry.authenticationRequired => BuyEntry.signIn,
            ExchangeTradingEntry.unavailable => BuyEntry.unavailable,
          },
        )
        .mapErr((_) => const BuyUnexpectedFailure());
  }
}
