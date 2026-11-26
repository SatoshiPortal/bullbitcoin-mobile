import 'package:exchange/exchange.dart';

/// Whether the scam-warning consent is on the session's account (the
/// re-read after an unknown consent write).
class GetFundingConsentUsecase {
  final Exchange _exchange;

  const GetFundingConsentUsecase(this._exchange);

  Future<ExchangeRead<bool>> execute(ExchangeSession session) =>
      _exchange.funding.consentOnAccount(session);
}
