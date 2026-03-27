import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_domain_error.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';

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
  final FundingGatewayPort _fundingGateway;

  const GetFundingDetailsUsecase({required FundingGatewayPort fundingGateway})
    : _fundingGateway = fundingGateway;

  Future<GetFundingDetailsResult> execute(GetFundingDetailsQuery query) async {
    try {
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

      final fundingDetails = await _fundingGateway.getFundingDetails(
        fundingMethod: fundingMethod,
      );

      return GetFundingDetailsResult(fundingDetails: fundingDetails);
    } on FundExchangeDomainError catch (e) {
      throw FundExchangeApplicationError.fromDomainError(e);
    } on FundExchangeApplicationError {
      rethrow;
    } catch (e) {
      throw FundExchangeUnknownError(message: '$e');
    }
  }
}
