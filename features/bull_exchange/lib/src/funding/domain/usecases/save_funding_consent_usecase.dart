import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Records the scam-warning consent on the session's account.
class SaveFundingConsentUsecase {
  final Exchange _exchange;

  const SaveFundingConsentUsecase(this._exchange);

  Future<Result<void, ExchangeWriteFailure>> execute(ExchangeSession session) =>
      _exchange.funding.consent(session);
}
