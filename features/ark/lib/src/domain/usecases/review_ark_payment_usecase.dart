import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import 'parse_ark_destination_usecase.dart';
import 'quote_ark_operation_usecase.dart';

final class ReviewArkPaymentUsecase {
  final ParseArkDestinationUsecase _parse;
  final QuoteArkOperationUsecase _quote;
  const ReviewArkPaymentUsecase(this._parse, this._quote);
  Future<Result<ArkQuote, ArkFailure>> execute(
    ArkAccountId account, {
    required String destination,
    required String amount,
  }) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(amount)) {
      return const Err(ArkInvalidRequestFailure());
    }
    final value = BigInt.tryParse(amount);
    if (value == null ||
        value <= BigInt.zero ||
        value > BigInt.from(2100000000000000)) {
      return const Err(ArkInvalidRequestFailure());
    }
    switch (_parse.execute(destination, network: account.network)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final valueDestination):
        return _quote.execute(
          account,
          ArkQuoteRequest.payment(
            destination: valueDestination,
            amount: Sats(value),
          ),
        );
    }
  }
}
