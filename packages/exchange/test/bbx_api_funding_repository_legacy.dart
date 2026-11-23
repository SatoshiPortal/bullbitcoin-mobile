// Historical failure identities in the fixture, not production failure types.
abstract final class FundExchangeConsentRegistrationFailure {}

abstract final class FundExchangeCopRequestInvalidFailure {}

abstract final class FundExchangeKycIncompleteFailure {}

abstract final class FundExchangeNetworkFailure {}

abstract final class FundExchangeNoInstitutionsFailure {}

abstract final class FundExchangeNotAuthenticatedFailure {}

abstract final class FundExchangeOptionNotPermittedFailure {}

abstract final class FundExchangePaymentOptionUnavailableFailure {}

abstract final class FundExchangeRequestInvalidFailure {}

abstract final class FundExchangeSepaVirtualPaymentInactiveFailure {}

abstract final class FundExchangeSinpeNotRegisteredFailure {}

abstract final class FundExchangeUnexpectedFailure {}

/// What the removed BullBitcoinApiFundingRepository sent and gave for each
/// case of `bbx_api_funding_repository_test.dart`: the requests, and
/// `['ok', value]` or `[failure type, log message]`.
final oldRepository = <String, Object?>{
  'details EmailETransfer': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_CAD_EMAIL_TRANSFER_APL","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {
        'type': 'etransfer',
        'secretQuestion': 'ABC123',
        'beneficiaryName': 'Bull Bitcoin',
        'beneficiaryEmail': 'pay@example.com',
      },
    ],
  ),
  'details BankTransferWire': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_CAD_WIRE_TRANSFER_SCU","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {
        'type': 'wire',
        'code': 'ABC123',
        'beneficiaryName': 'Bull Bitcoin',
        'bankAccountDetails': 'details',
        'iban': 'DE89370400440532013000',
        'swift': 'SWIFTXX',
        'institutionNumber': '1',
        'transitNumber': '12345',
        'accountNumber': '1234567',
        'routingNumber': '021000021',
        'beneficiaryAddress': '1 Main St',
        'bankAddress': '2 Bank St',
        'bankName': 'Bank',
      },
    ],
  ),
  'details OnlineBillPayment': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_CAD_BILL_PAYMENT_APL","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {'type': 'bill', 'code': 'ABC123', 'billerName': 'Bull Bitcoin Biller'},
    ],
  ),
  'details CanadaPost': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_CAD_LOADHUB","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {'type': 'canadaPost', 'code': 'ABC123'},
    ],
  ),
  'details InstantSepa': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_CJ_IBAN","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {
        'type': 'instantSepa',
        'code': 'ABC123',
        'iban': 'DE89370400440532013000',
        'bic': 'BICXX',
        'beneficiaryName': 'Bull Bitcoin',
        'beneficiaryAddress': '1 Main St',
        'bankAccountCountry': 'FR',
      },
    ],
  ),
  'details RegularSepa': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {
        'type': 'regularSepa',
        'code': 'ABC123',
        'iban': 'DE89370400440532013000',
        'bic': 'BICXX',
        'beneficiaryName': 'Bull Bitcoin',
        'beneficiaryAddress': '1 Main St',
        'bankCountry': 'DE',
      },
    ],
  ),
  'details SpeiTransfer': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_MXN_BITSO_CLABE","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {
        'type': 'spei',
        'code': 'ABC123',
        'bankName': 'Bank',
        'beneficiaryName': 'Bull Bitcoin',
        'clabe': '002010077777777771',
      },
    ],
  ),
  'details Sinpe': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_CRC_RDV_SINPE","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {
        'type': 'sinpe',
        'number': '88888888',
        'beneficiaryName': 'Bull Bitcoin',
      },
    ],
  ),
  'details CrIbanCrc': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_CRC_RDV_IBAN","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {
        'type': 'crIbanCrc',
        'iban': 'DE89370400440532013000',
        'code': 'ABC123',
        'beneficiaryName': 'Bull Bitcoin',
        'cedulaJuridica': '3-101-123456',
      },
    ],
  ),
  'details CrIbanUsd': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_USD_RDV_IBAN","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {
        'type': 'crIbanUsd',
        'iban': 'DE89370400440532013000',
        'code': 'ABC123',
        'beneficiaryName': 'Bull Bitcoin',
        'cedulaJuridica': '3-101-123456',
      },
    ],
  ),
  'details ArsBankTransfer': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_ARS_BITSO","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      'ok',
      {
        'type': 'ars',
        'beneficiaryName': 'Bull Bitcoin',
        'cvu': '0000003100010000000001',
      },
    ],
  ),
  'details CopBankTransfer': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":50000,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      'ok',
      {'type': 'cop', 'paymentLink': 'https://pay.example/cop'},
    ],
  ),
  'institutions Jurisdiction.canada': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"ca"}}',
      ),
    ],
    [
      FundExchangeNoInstitutionsFailure,
      'listInstitutionCodes returned no usable institution',
    ],
  ),
  'institutions Jurisdiction.europe': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"eu"}}',
      ),
    ],
    [
      FundExchangeNoInstitutionsFailure,
      'listInstitutionCodes returned no usable institution',
    ],
  ),
  'institutions Jurisdiction.mexico': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"mx"}}',
      ),
    ],
    [
      FundExchangeNoInstitutionsFailure,
      'listInstitutionCodes returned no usable institution',
    ],
  ),
  'institutions Jurisdiction.costaRica': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"cr"}}',
      ),
    ],
    [
      FundExchangeNoInstitutionsFailure,
      'listInstitutionCodes returned no usable institution',
    ],
  ),
  'institutions Jurisdiction.argentina': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"ar"}}',
      ),
    ],
    [
      FundExchangeNoInstitutionsFailure,
      'listInstitutionCodes returned no usable institution',
    ],
  ),
  'institutions Jurisdiction.colombia': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeNoInstitutionsFailure,
      'listInstitutionCodes returned no usable institution',
    ],
  ),
  'institutions kept and skipped': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      'ok',
      [('BC01', 'Bancolombia'), ('DV01', 'Davivienda')],
    ],
  ),
  'no institutions {result: {elements: []}}': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"ca"}}',
      ),
    ],
    [
      FundExchangeNoInstitutionsFailure,
      'listInstitutionCodes returned no usable institution',
    ],
  ),
  'no institutions {result: {}}': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"ca"}}',
      ),
    ],
    [
      FundExchangeNoInstitutionsFailure,
      'listInstitutionCodes returned no usable institution',
    ],
  ),
  'no institutions {result: {elements: [{code: , name: , accountTypes: []}]}}':
      (
        [
          (
            '/ak/api-recipients',
            '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"ca"}}',
          ),
        ],
        [
          FundExchangeNoInstitutionsFailure,
          'listInstitutionCodes returned no usable institution',
        ],
      ),
  'consent true': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    ['ok', null],
  ),
  'consent null': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    ['ok', null],
  ),
  'consent {success: true}': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    ['ok', null],
  ),
  'consent {success: false}': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    ['ok', null],
  ),
  'consent ok': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    ['ok', null],
  ),
  'getFundingDetails: ERR_ORD_PO404': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangePaymentOptionUnavailableFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails: ERR_RCP_PO404': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangeOptionNotPermittedFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails: ERR_RCP_POSINPE404': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangeSinpeNotRegisteredFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails: ERR_ORD_KYC400': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangeKycIncompleteFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails: ERR_ORD_COP400': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangeCopRequestInvalidFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails: ERR_ORD_CSRCP400': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangeSepaVirtualPaymentInactiveFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails: ERR_RCP_400': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangeRequestInvalidFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails: ERR_SOMETHING_NEW': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangeUnexpectedFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails: a numeric API code': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangeUnexpectedFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails: a JSON-RPC error without data': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'refused'],
  ),
  'getFundingDetails: a non-object error refused': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: String'],
  ),
  'getFundingDetails: a non-object error 42': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: int'],
  ),
  'getFundingDetails: a non-object error true': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: bool'],
  ),
  'getFundingDetails: a non-object error []': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: List<dynamic>'],
  ),
  'getFundingDetails: status 503': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'HTTP 503'],
  ),
  'getFundingDetails: status 204': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'HTTP 204'],
  ),
  'getFundingDetails: a body that is not an object': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Response is not JSON'],
  ),
  'getFundingDetails: a result that is not an object': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [
      FundExchangeUnexpectedFailure,
      'getUserPaymentProcessorCode returned no funding details',
    ],
  ),
  'getFundingDetails: a missing result': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Missing RPC result'],
  ),
  'getFundingDetails: a DioExceptionType.connectionTimeout': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: connectionTimeout'],
  ),
  'getFundingDetails: a DioExceptionType.sendTimeout': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: sendTimeout'],
  ),
  'getFundingDetails: a DioExceptionType.receiveTimeout': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: receiveTimeout'],
  ),
  'getFundingDetails: a DioExceptionType.badCertificate': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Transport failure: badCertificate'],
  ),
  'getFundingDetails: a DioExceptionType.badResponse': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Transport failure: badResponse'],
  ),
  'getFundingDetails: a DioExceptionType.connectionError': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: connectionError'],
  ),
  'getFundingDetails: a DioExceptionType.transformTimeout': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode","params":{"paymentProcessorCode":"IN_EUR_SEPA_DELUBAC","bankCode":null,"amount":null,"callbackUrl":null}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Transport failure: transformTimeout'],
  ),
  'getFundingDetails: no key': (
    [],
    [FundExchangeNotAuthenticatedFailure, null],
  ),
  'getFundingDetails: unreadable key': (
    [],
    [FundExchangeUnexpectedFailure, 'Exchange credential unavailable'],
  ),
  'getFundingDetails (COP): ERR_ORD_PO404': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangePaymentOptionUnavailableFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails (COP): ERR_RCP_PO404': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangeOptionNotPermittedFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails (COP): ERR_RCP_POSINPE404': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangeSinpeNotRegisteredFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails (COP): ERR_ORD_KYC400': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangeKycIncompleteFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails (COP): ERR_ORD_COP400': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangeCopRequestInvalidFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails (COP): ERR_ORD_CSRCP400': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangeSepaVirtualPaymentInactiveFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails (COP): ERR_RCP_400': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangeRequestInvalidFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails (COP): ERR_SOMETHING_NEW': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangeUnexpectedFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails (COP): a numeric API code': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangeUnexpectedFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'getFundingDetails (COP): a JSON-RPC error without data': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'refused'],
  ),
  'getFundingDetails (COP): a non-object error refused': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: String'],
  ),
  'getFundingDetails (COP): a non-object error 42': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: int'],
  ),
  'getFundingDetails (COP): a non-object error true': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: bool'],
  ),
  'getFundingDetails (COP): a non-object error []': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: List<dynamic>'],
  ),
  'getFundingDetails (COP): status 503': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'HTTP 503'],
  ),
  'getFundingDetails (COP): status 204': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'HTTP 204'],
  ),
  'getFundingDetails (COP): a body that is not an object': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Response is not JSON'],
  ),
  'getFundingDetails (COP): a result that is not an object': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [
      FundExchangeUnexpectedFailure,
      'getCopPaymentLink returned a non-string payment link',
    ],
  ),
  'getFundingDetails (COP): a missing result': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Missing RPC result'],
  ),
  'getFundingDetails (COP): a DioExceptionType.connectionTimeout': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: connectionTimeout'],
  ),
  'getFundingDetails (COP): a DioExceptionType.sendTimeout': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: sendTimeout'],
  ),
  'getFundingDetails (COP): a DioExceptionType.receiveTimeout': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: receiveTimeout'],
  ),
  'getFundingDetails (COP): a DioExceptionType.badCertificate': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Transport failure: badCertificate'],
  ),
  'getFundingDetails (COP): a DioExceptionType.badResponse': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Transport failure: badResponse'],
  ),
  'getFundingDetails (COP): a DioExceptionType.connectionError': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: connectionError'],
  ),
  'getFundingDetails (COP): a DioExceptionType.transformTimeout': (
    [
      (
        '/ak/api-orders',
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":{"paymentProcessorCode":null,"bankCode":"BC01","amount":1,"callbackUrl":"https://app.bullbitcoin.com"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Transport failure: transformTimeout'],
  ),
  'getFundingDetails (COP): no key': (
    [],
    [FundExchangeNotAuthenticatedFailure, null],
  ),
  'getFundingDetails (COP): unreadable key': (
    [],
    [FundExchangeUnexpectedFailure, 'Exchange credential unavailable'],
  ),
  'listInstitutions: ERR_ORD_PO404': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangePaymentOptionUnavailableFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'listInstitutions: ERR_RCP_PO404': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeOptionNotPermittedFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'listInstitutions: ERR_RCP_POSINPE404': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeSinpeNotRegisteredFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'listInstitutions: ERR_ORD_KYC400': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeKycIncompleteFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'listInstitutions: ERR_ORD_COP400': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeCopRequestInvalidFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'listInstitutions: ERR_ORD_CSRCP400': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeSepaVirtualPaymentInactiveFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'listInstitutions: ERR_RCP_400': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeRequestInvalidFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'listInstitutions: ERR_SOMETHING_NEW': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeUnexpectedFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'listInstitutions: a numeric API code': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeUnexpectedFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'listInstitutions: a JSON-RPC error without data': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'refused'],
  ),
  'listInstitutions: a non-object error refused': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: String'],
  ),
  'listInstitutions: a non-object error 42': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: int'],
  ),
  'listInstitutions: a non-object error true': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: bool'],
  ),
  'listInstitutions: a non-object error []': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Non-object RPC error: List<dynamic>'],
  ),
  'listInstitutions: status 503': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'HTTP 503'],
  ),
  'listInstitutions: status 204': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'HTTP 204'],
  ),
  'listInstitutions: a body that is not an object': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Response is not JSON'],
  ),
  'listInstitutions: a result that is not an object': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [
      FundExchangeUnexpectedFailure,
      'listInstitutionCodes returned no result map',
    ],
  ),
  'listInstitutions: a missing result': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Missing RPC result'],
  ),
  'listInstitutions: a DioExceptionType.connectionTimeout': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: connectionTimeout'],
  ),
  'listInstitutions: a DioExceptionType.sendTimeout': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: sendTimeout'],
  ),
  'listInstitutions: a DioExceptionType.receiveTimeout': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: receiveTimeout'],
  ),
  'listInstitutions: a DioExceptionType.badCertificate': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Transport failure: badCertificate'],
  ),
  'listInstitutions: a DioExceptionType.badResponse': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Transport failure: badResponse'],
  ),
  'listInstitutions: a DioExceptionType.connectionError': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: connectionError'],
  ),
  'listInstitutions: a DioExceptionType.transformTimeout': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes","params":{"countryCode":"co"}}',
      ),
    ],
    [FundExchangeUnexpectedFailure, 'Transport failure: transformTimeout'],
  ),
  'listInstitutions: no key': ([], [FundExchangeNotAuthenticatedFailure, null]),
  'listInstitutions: unreadable key': (
    [],
    [FundExchangeUnexpectedFailure, 'Exchange credential unavailable'],
  ),
  'registerResponsibilityConsent: ERR_ORD_PO404': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'registerResponsibilityConsent: ERR_RCP_PO404': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'registerResponsibilityConsent: ERR_RCP_POSINPE404': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'registerResponsibilityConsent: ERR_ORD_KYC400': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'registerResponsibilityConsent: ERR_ORD_COP400': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'registerResponsibilityConsent: ERR_ORD_CSRCP400': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'registerResponsibilityConsent: ERR_RCP_400': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'registerResponsibilityConsent: ERR_SOMETHING_NEW': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'registerResponsibilityConsent: a numeric API code': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Recipient DE89370400440532013000 is not active',
    ],
  ),
  'registerResponsibilityConsent: a JSON-RPC error without data': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeConsentRegistrationFailure, 'refused'],
  ),
  'registerResponsibilityConsent: a non-object error refused': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeConsentRegistrationFailure, 'Non-object RPC error: String'],
  ),
  'registerResponsibilityConsent: a non-object error 42': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeConsentRegistrationFailure, 'Non-object RPC error: int'],
  ),
  'registerResponsibilityConsent: a non-object error true': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeConsentRegistrationFailure, 'Non-object RPC error: bool'],
  ),
  'registerResponsibilityConsent: a non-object error []': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Non-object RPC error: List<dynamic>',
    ],
  ),
  'registerResponsibilityConsent: status 503': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeConsentRegistrationFailure, 'HTTP 503'],
  ),
  'registerResponsibilityConsent: status 204': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeConsentRegistrationFailure, 'HTTP 204'],
  ),
  'registerResponsibilityConsent: a body that is not an object': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeConsentRegistrationFailure, 'Response is not JSON'],
  ),
  'registerResponsibilityConsent: a result that is not an object': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    ['ok', null],
  ),
  'registerResponsibilityConsent: a missing result': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    ['ok', null],
  ),
  'registerResponsibilityConsent: a DioExceptionType.connectionTimeout': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: connectionTimeout'],
  ),
  'registerResponsibilityConsent: a DioExceptionType.sendTimeout': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: sendTimeout'],
  ),
  'registerResponsibilityConsent: a DioExceptionType.receiveTimeout': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: receiveTimeout'],
  ),
  'registerResponsibilityConsent: a DioExceptionType.badCertificate': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Transport failure: badCertificate',
    ],
  ),
  'registerResponsibilityConsent: a DioExceptionType.badResponse': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeConsentRegistrationFailure, 'Transport failure: badResponse'],
  ),
  'registerResponsibilityConsent: a DioExceptionType.connectionError': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [FundExchangeNetworkFailure, 'Unreachable: connectionError'],
  ),
  'registerResponsibilityConsent: a DioExceptionType.transformTimeout': (
    [
      (
        '/ak/api-users',
        '{"jsonrpc":"2.0","id":"0","method":"registerResponsibilityConsent","params":{}}',
      ),
    ],
    [
      FundExchangeConsentRegistrationFailure,
      'Transport failure: transformTimeout',
    ],
  ),
  'registerResponsibilityConsent: no key': (
    [],
    [FundExchangeNotAuthenticatedFailure, null],
  ),
  'registerResponsibilityConsent: unreadable key': (
    [],
    [FundExchangeUnexpectedFailure, 'Exchange credential unavailable'],
  ),
};
