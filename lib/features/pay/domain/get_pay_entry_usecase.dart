import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';

enum PayEntry { allowed, signIn, unavailable }

class GetPayEntryUsecase {
  const GetPayEntryUsecase(this._exchange);
  final ExchangeFacade _exchange;

  Future<Result<PayEntry, PayFailure>> execute({required bool isIOS}) async {
    final result = await _exchange.tradingEntry(isIOS: isIOS);
    return result
        .map(
          (entry) => switch (entry) {
            ExchangeTradingEntry.allowed => PayEntry.allowed,
            ExchangeTradingEntry.authenticationRequired => PayEntry.signIn,
            ExchangeTradingEntry.unavailable => PayEntry.unavailable,
          },
        )
        .mapErr((_) => const PayUnexpectedFailure());
  }
}
