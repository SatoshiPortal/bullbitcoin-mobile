import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';

enum SellEntry { allowed, signIn, unavailable }

class GetSellEntryUsecase {
  const GetSellEntryUsecase(this._exchange);
  final ExchangeFacade _exchange;

  Future<Result<SellEntry, SellFailure>> execute({required bool isIOS}) async {
    final result = await _exchange.tradingEntry(isIOS: isIOS);
    return result
        .map(
          (entry) => switch (entry) {
            ExchangeTradingEntry.allowed => SellEntry.allowed,
            ExchangeTradingEntry.authenticationRequired => SellEntry.signIn,
            ExchangeTradingEntry.unavailable => SellEntry.unavailable,
          },
        )
        .mapErr((_) => const SellUnexpectedFailure());
  }
}
