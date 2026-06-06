import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'get_funding_details_request_params_model.freezed.dart';
part 'get_funding_details_request_params_model.g.dart';

@freezed
sealed class GetFundingDetailsRequestParamsModel
    with _$GetFundingDetailsRequestParamsModel {
  const factory GetFundingDetailsRequestParamsModel({
    String? paymentProcessorCode,
    String? bankCode,
    int? amount,
    String? callbackUrl,
  }) = _GetFundingDetailsRequestParamsModel;

  const GetFundingDetailsRequestParamsModel._();

  factory GetFundingDetailsRequestParamsModel.fromFundingMethod(
    FundingMethod fundingMethod,
  ) {
    final ppCode = switch (fundingMethod) {
      EmailETransfer() => 'IN_CAD_EMAIL_TRANSFER_APL',
      BankTransferWire() => 'IN_CAD_WIRE_TRANSFER_SCU',
      OnlineBillPayment() => 'IN_CAD_BILL_PAYMENT_APL',
      CanadaPost() => 'IN_CAD_LOADHUB',
      InstantSepa() => 'IN_EUR_CJ_IBAN',
      RegularSepa() => 'IN_EUR_SEPA_DELUBAC',
      SpeiTransfer() => 'IN_MXN_BITSO_CLABE',
      Sinpe() => 'IN_CRC_RDV_SINPE',
      CrIbanCrc() => 'IN_CRC_RDV_IBAN',
      CrIbanUsd() => 'IN_USD_RDV_IBAN',
      ArsBankTransfer() => 'IN_ARS_BITSO',
      CopBankTransfer() => null,
    };

    return GetFundingDetailsRequestParamsModel(
      paymentProcessorCode: ppCode,
      bankCode: fundingMethod is CopBankTransfer
          ? fundingMethod.bankCode
          : null,
      amount: fundingMethod is CopBankTransfer ? fundingMethod.amountCop : null,
      callbackUrl: fundingMethod is CopBankTransfer
          ? ApiServiceConstants.bbAppUrl
          : null,
    );
  }

  factory GetFundingDetailsRequestParamsModel.fromJson(
    Map<String, dynamic> json,
  ) => _$GetFundingDetailsRequestParamsModelFromJson(json);
}
