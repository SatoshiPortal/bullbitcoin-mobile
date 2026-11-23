import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/domain/entities/account_owner_name.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The legal name on the user's exchange account, which a virtual IBAN is
/// issued in.
class GetAccountOwnerNameUsecase {
  final Exchange _exchange;

  const GetAccountOwnerNameUsecase(this._exchange);

  @useResult
  Future<Result<AccountOwnerName, RecipientsFailure>> execute() async {
    switch (await _exchange.getUserSummary()) {
      case Ok(value: UserSummary(:final profile)):
        return Ok(
          AccountOwnerName(
            firstName: profile.firstName.trim(),
            lastName: profile.lastName.trim(),
          ),
        );
      case Err(:final failure):
        log.warning(
          'Could not read the exchange summary for the account owner name',
          error: failure.runtimeType,
        );
        return const Err(RecipientsUnexpectedFailure());
    }
  }
}
