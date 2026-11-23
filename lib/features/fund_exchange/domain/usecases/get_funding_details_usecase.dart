import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../map_funding_failure.dart';

sealed class GetFundingDetailsQuery {
  const GetFundingDetailsQuery();
}

class GetEmailETransferDetails extends GetFundingDetailsQuery {
  const GetEmailETransferDetails();
}

class GetBankTransferWireDetails extends GetFundingDetailsQuery {
  const GetBankTransferWireDetails();
}

class GetOnlineBillPaymentDetails extends GetFundingDetailsQuery {
  const GetOnlineBillPaymentDetails();
}

class GetCanadaPostDetails extends GetFundingDetailsQuery {
  const GetCanadaPostDetails();
}

class GetInstantSepaDetails extends GetFundingDetailsQuery {
  const GetInstantSepaDetails();
}

class GetRegularSepaDetails extends GetFundingDetailsQuery {
  const GetRegularSepaDetails();
}

class GetSpeiTransferDetails extends GetFundingDetailsQuery {
  const GetSpeiTransferDetails();
}

class GetSinpeDetails extends GetFundingDetailsQuery {
  const GetSinpeDetails();
}

class GetCrIbanCrcDetails extends GetFundingDetailsQuery {
  const GetCrIbanCrcDetails();
}

class GetCrIbanUsdDetails extends GetFundingDetailsQuery {
  const GetCrIbanUsdDetails();
}

class GetArsBankTransferDetails extends GetFundingDetailsQuery {
  const GetArsBankTransferDetails();
}

class GetCopBankTransferDetails extends GetFundingDetailsQuery {
  final String bankCode;
  final int amountCop;

  const GetCopBankTransferDetails({
    required this.bankCode,
    required this.amountCop,
  });
}

class GetFundingDetailsResult {
  final FundingDetails fundingDetails;

  const GetFundingDetailsResult({required this.fundingDetails});
}

class GetFundingDetailsUsecase {
  final ExchangeFunding _funding;

  const GetFundingDetailsUsecase({required this._funding});

  @useResult
  Future<Result<GetFundingDetailsResult, FundExchangeFailure>> execute(
    GetFundingDetailsQuery query,
  ) async {
    final fundingMethod = switch (query) {
      GetEmailETransferDetails() => EmailETransfer(),
      GetBankTransferWireDetails() => BankTransferWire(),
      GetOnlineBillPaymentDetails() => OnlineBillPayment(),
      GetCanadaPostDetails() => CanadaPost(),
      GetInstantSepaDetails() => InstantSepa(),
      GetRegularSepaDetails() => RegularSepa(),
      GetSpeiTransferDetails() => SpeiTransfer(),
      GetSinpeDetails() => Sinpe(),
      GetCrIbanCrcDetails() => CrIbanCrc(),
      GetCrIbanUsdDetails() => CrIbanUsd(),
      GetArsBankTransferDetails() => ArsBankTransfer(),
      GetCopBankTransferDetails(:final bankCode, :final amountCop) =>
        CopBankTransfer(bankCode: bankCode, amountCop: amountCop),
    };

    final result = (await _funding.getFundingDetails(
      fundingMethod: fundingMethod,
    )).mapErr(mapFundingFailure);

    return result.map(
      (details) => GetFundingDetailsResult(fundingDetails: details),
    );
  }
}
