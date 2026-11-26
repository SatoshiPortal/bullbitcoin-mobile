import 'package:exchange/exchange.dart';

/// Records the scam-warning consent on the session's account.
class SaveFundingConsentUsecase {
  final Exchange _exchange;

  const SaveFundingConsentUsecase(this._exchange);

  Future<ExchangeWrite<void>> execute(ExchangeSession session) =>
      _exchange.funding.consent(session);
}
