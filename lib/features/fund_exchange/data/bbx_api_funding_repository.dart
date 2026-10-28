import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/fund_exchange/data/funding_datasource_exception.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// [FundingRepository] for one environment on the shared `bbx_api` client.
class BbxApiFundingRepository implements FundingRepository {
  final BbxApiDatasource _api;

  BbxApiFundingRepository({required this._api});

  @override
  @useResult
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async {
    final isCop = fundingMethod is CopBankTransfer;
    final method = isCop ? 'getCopPaymentLink' : 'getUserPaymentProcessorCode';

    try {
      if (fundingMethod is CopBankTransfer) {
        final link = _unwrap(
          await _api.orders.getCopPaymentLink(
            bbx.CopPaymentLinkPayload(
              bankCode: fundingMethod.bankCode,
              amount: fundingMethod.amountCop.toDouble(),
              callbackUrl: ApiServiceConstants.bbAppUrl,
            ),
          ),
        );
        return Ok(CopBankTransferFundingDetails(paymentLink: link));
      }

      final details = _unwrap(
        await _api.recipients.userPaymentProcessorCode(
          _paymentProcessor(fundingMethod),
        ),
      );
      return Ok(_fundingDetails(details, fundingMethod));
    } on FundingDatasourceException catch (e, st) {
      log.warning('$method failed', error: e, trace: st);
      return Err(_mapException(e));
    } catch (e, st) {
      log.severe(message: '$method failed', error: e, trace: st);
      return Err(FundExchangeUnexpectedFailure(e.toString()));
    }
  }

  @override
  @useResult
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction}) async {
    const method = 'listInstitutionCodes';

    try {
      final codes = _unwrap(
        await _api.recipients.listInstitutionCodesByCountryCode(
          jurisdiction.code.toLowerCase(),
        ),
      );
      final institutions = codes.items
          .map((code) {
            try {
              return FundingInstitution.create(
                code: code.code,
                name: code.name,
              );
            } catch (err, st) {
              log.warning(
                'Skipped an unusable institution element',
                error: err,
                trace: st,
              );
              return null;
            }
          })
          .whereType<FundingInstitution>()
          .toList();

      if (institutions.isEmpty) {
        return const Err(
          FundExchangeNoInstitutionsFailure(
            'listInstitutionCodes returned no usable institution',
          ),
        );
      }
      return Ok(institutions);
    } on FundingDatasourceException catch (e, st) {
      log.warning('$method failed', error: e, trace: st);
      return Err(_mapException(e));
    } catch (e, st) {
      log.severe(message: '$method failed', error: e, trace: st);
      return Err(FundExchangeUnexpectedFailure(e.toString()));
    }
  }

  @override
  @useResult
  Future<Result<void, FundExchangeFailure>>
  registerResponsibilityConsent() async {
    const method = 'registerResponsibilityConsent';

    try {
      _unwrap(await _api.users.consentToScamWarning());
      return const Ok(null);
    } on FundingDatasourceException catch (e, st) {
      log.warning('$method failed', error: e, trace: st);
      return Err(switch (e) {
        FundingUnreachableException() => FundExchangeNetworkFailure(
          e.logMessage,
        ),
        _ => FundExchangeConsentRegistrationFailure(e.logMessage),
      });
    } catch (e, st) {
      log.severe(message: '$method failed', error: e, trace: st);
      return Err(FundExchangeConsentRegistrationFailure(e.toString()));
    }
  }

  /// The data, or the matching [FundingDatasourceException].
  T _unwrap<T>(bbx.ApiResult<T> result) {
    switch (result) {
      case bbx.Success(:final data):
        return data;
      case bbx.Failure(:final error):
        error.reportBadCertificate();
        if (error.rpcErrorData != null) {
          throw FundingRpcException(
            apiCode: error.apiErrorCode,
            logMessage: error.serverMessage,
          );
        }
        final status = error.httpStatus;
        if (status != null && status >= 400) {
          throw FundingNetworkException('HTTP $status');
        }
        if (error.isUnreachable) {
          throw FundingUnreachableException('Unreachable: ${error.kind.name}');
        }
        throw FundingResponseException('API error ${error.code ?? 'no code'}');
    }
  }

  FundExchangeFailure _mapException(FundingDatasourceException e) =>
      switch (e) {
        FundingRpcException(:final apiCode) =>
          switch (bbx.BBApiErrorCode.fromString(apiCode)) {
            bbx.BBApiErrorCode.errOrdPo404 =>
              FundExchangePaymentOptionUnavailableFailure(e.logMessage),
            bbx.BBApiErrorCode.errRcpPo404 =>
              FundExchangeOptionNotPermittedFailure(e.logMessage),
            bbx.BBApiErrorCode.errRcpPosinpe404 =>
              FundExchangeSinpeNotRegisteredFailure(e.logMessage),
            bbx.BBApiErrorCode.errOrdKyc400 => FundExchangeKycIncompleteFailure(
              e.logMessage,
            ),
            bbx.BBApiErrorCode.errOrdCop400 =>
              FundExchangeCopRequestInvalidFailure(e.logMessage),
            bbx.BBApiErrorCode.errOrdCsrcp400 =>
              FundExchangeSepaVirtualPaymentInactiveFailure(e.logMessage),
            bbx.BBApiErrorCode.errRcp400 => FundExchangeRequestInvalidFailure(
              e.logMessage,
            ),
            _ => FundExchangeUnexpectedFailure(e.logMessage),
          },
        FundingUnreachableException() => FundExchangeNetworkFailure(
          e.logMessage,
        ),
        FundingNetworkException() || FundingResponseException() =>
          FundExchangeUnexpectedFailure(e.logMessage),
      };

  static bbx.InPaymentProcessor _paymentProcessor(FundingMethod method) =>
      switch (method) {
        EmailETransfer() => bbx.InPaymentProcessor.inCadEmailTransferApl,
        BankTransferWire() => bbx.InPaymentProcessor.inCadWireTransferScu,
        OnlineBillPayment() => bbx.InPaymentProcessor.inCadBillPaymentApl,
        CanadaPost() => bbx.InPaymentProcessor.inCadLoadhub,
        InstantSepa() => bbx.InPaymentProcessor.inEUCJIban,
        RegularSepa() => bbx.InPaymentProcessor.inEURSepaDelubac,
        SpeiTransfer() => bbx.InPaymentProcessor.inMxnBitsoClabe,
        Sinpe() => bbx.InPaymentProcessor.inCrcRdvSinpe,
        CrIbanCrc() => bbx.InPaymentProcessor.inCrcRdvIban,
        CrIbanUsd() => bbx.InPaymentProcessor.inUsdRdvIban,
        ArsBankTransfer() => bbx.InPaymentProcessor.inArsBitso,
        CopBankTransfer() => throw ArgumentError.value(
          method,
          'method',
          'COP is funded through a payment link',
        ),
      };

  static String _required(String? value, String field) =>
      value ??
      (throw FundingResponseException('Funding details without $field'));

  static FundingDetails _fundingDetails(
    bbx.FundingDetails d,
    FundingMethod method,
  ) {
    String code() => _required(d.code, 'code');
    String beneficiaryName() =>
        _required(d.beneficiaryName, 'beneficiary name');
    return switch (method) {
      EmailETransfer() => ETransferFundingDetails(
        secretQuestion: code(),
        beneficiaryName: beneficiaryName(),
        beneficiaryEmail: _required(d.beneficiaryEmail, 'beneficiary email'),
      ),
      BankTransferWire() => WireFundingDetails(
        code: code(),
        beneficiaryName: beneficiaryName(),
        bankAccountDetails: _required(d.bankAccountDetails, 'account details'),
        iban: _required(d.iban, 'IBAN'),
        swift: _required(d.swift, 'SWIFT'),
        institutionNumber: _required(d.institutionNumber, 'institution'),
        transitNumber: _required(d.transitNumber, 'transit'),
        accountNumber: _required(d.accountNumber, 'account number'),
        routingNumber: _required(d.routingNumber, 'routing number'),
        beneficiaryAddress: _required(d.beneficiaryAddress, 'address'),
        bankAddress: _required(d.bankAddress, 'bank address'),
        bankName: _required(d.bankName, 'bank name'),
      ),
      OnlineBillPayment() => BillPaymentFundingDetails(
        code: code(),
        billerName: _required(d.billerName, 'biller name'),
      ),
      CanadaPost() => CanadaPostFundingDetails(code: code()),
      InstantSepa() => InstantSepaFundingDetails(
        code: code(),
        iban: _required(d.iban, 'IBAN'),
        bic: _required(d.bic, 'BIC'),
        beneficiaryName: beneficiaryName(),
        beneficiaryAddress: _required(d.beneficiaryAddress, 'address'),
        bankAccountCountry: _required(d.bankAccountCountry, 'country'),
      ),
      RegularSepa() => RegularSepaFundingDetails(
        code: code(),
        iban: _required(d.iban, 'IBAN'),
        bic: _required(d.bic, 'BIC'),
        beneficiaryName: beneficiaryName(),
        beneficiaryAddress: _required(d.beneficiaryAddress, 'address'),
        bankCountry: _required(d.bankCountry, 'bank country'),
      ),
      SpeiTransfer() => SpeiFundingDetails(
        code: code(),
        bankName: _required(d.bankName, 'bank name'),
        beneficiaryName: beneficiaryName(),
        clabe: _required(d.clabe, 'CLABE'),
      ),
      Sinpe() => SinpeFundingDetails(
        number: _required(d.phoneNumber, 'phone number'),
        beneficiaryName: beneficiaryName(),
      ),
      CrIbanCrc() => CrIbanCrcFundingDetails(
        iban: _required(d.iban, 'IBAN'),
        code: code(),
        beneficiaryName: beneficiaryName(),
        cedulaJuridica: _required(d.cedulaJuridica, 'cédula jurídica'),
      ),
      CrIbanUsd() => CrIbanUsdFundingDetails(
        iban: _required(d.iban, 'IBAN'),
        code: code(),
        beneficiaryName: beneficiaryName(),
        cedulaJuridica: _required(d.cedulaJuridica, 'cédula jurídica'),
      ),
      ArsBankTransfer() => ArsBankTransferFundingDetails(
        beneficiaryName: beneficiaryName(),
        cvu: _required(d.cvu, 'CVU'),
      ),
      CopBankTransfer() => throw ArgumentError.value(method, 'method'),
    };
  }
}
