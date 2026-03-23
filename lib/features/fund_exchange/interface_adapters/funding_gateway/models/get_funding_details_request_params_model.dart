import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'get_funding_details_request_params_model.freezed.dart';
part 'get_funding_details_request_params_model.g.dart';

@freezed
sealed class GetFundingDetailsRequestParamsModel
    with _$GetFundingDetailsRequestParamsModel {
  const factory GetFundingDetailsRequestParamsModel({
    required String jurisdiction,
    required String paymentMethod,
    String? bankCode,
    int? amount,
    String? callbackUrl,
  }) = _GetFundingDetailsRequestParamsModel;

  const GetFundingDetailsRequestParamsModel._();

  factory GetFundingDetailsRequestParamsModel.fromFundingMethod(
    FundingMethod fundingMethod,
  ) {
    final paymentMethod = switch (fundingMethod) {
      EmailETransfer() => 'eTransfer',
      BankTransferWire() => 'wire',
      OnlineBillPayment() => 'billPayment',
      CanadaPost() => 'canadaPost',
      InstantSepa() => 'instantSepa',
      RegularSepa() => 'regularSepa',
      SpeiTransfer() => 'spei',
      Sinpe() => 'sinpe',
      CrIbanCrc() => 'CRIbanCRC',
      CrIbanUsd() => 'CRIbanUSD',
      ArsBankTransfer() => 'eTransferAR',
      CopBankTransfer() => 'bankTransferCOP',
    };

    return GetFundingDetailsRequestParamsModel(
      jurisdiction: fundingMethod.jurisdiction.code,
      paymentMethod: paymentMethod,
      bankCode: fundingMethod is CopBankTransfer
          ? fundingMethod.bankCode
          : null,
      amount: fundingMethod is CopBankTransfer ? fundingMethod.amountCop : null,
      callbackUrl: fundingMethod is CopBankTransfer
          ? "https://app.bullbitcoin.com"
          : null,
    );
  }

  factory GetFundingDetailsRequestParamsModel.fromJson(
    Map<String, dynamic> json,
  ) => _$GetFundingDetailsRequestParamsModelFromJson(json);
}
