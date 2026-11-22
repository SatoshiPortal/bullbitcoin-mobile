import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_format_exception.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/recipients/cad_biller.dart';
import 'package:bbx_api/src/recipients/fiat_recipient.dart';
import 'package:bbx_api/src/recipients/institution.dart';
import 'package:bbx_api/src/recipients/my_recipient.dart';
import 'package:bbx_api/src/recipients/new_fiat_recipient.dart';
import 'package:bbx_api/src/recipients/payment_processor_details.dart';
import 'package:bbx_api/src/recipients/recipients_wire.dart';
import 'package:bbx_api/src/recipients/virtual_accounts.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The `api-recipients` endpoint: payout recipients, the virtual IBAN, SEPA
/// virtual payees and funding instructions.
///
/// The fiat recipient calls ask for version 2 of the API with the
/// `x-api-version` header; the others use the default version.
final class RecipientsApi {
  static const endpoint = '/ak/api-recipients';
  static const _v2 = {'x-api-version': '2.0.0'};

  final BbxTransport _transport;

  @internal
  RecipientsApi(this._transport);

  /// The user's recipients, filtered by `recipientType` and `isDefault`
  /// when given. A missing element list is empty.
  Future<Result<List<MyRecipient>, BbxFailure>> listMyRecipients({
    List<String>? recipientTypes,
    bool? isDefault,
  }) => _transport.request(
    endpoint,
    'listMyRecipients',
    params: {
      'filters': {'recipientTypes': ?recipientTypes, 'isDefault': ?isDefault},
    },
    read: (result) =>
        readList(_result(result)['elements'], 'elements', parseMyRecipient),
  );

  /// Creates a recipient of [recipientType] paid to [address].
  Future<Result<MyRecipient, BbxFailure>> createMyRecipient({
    required String recipientType,
    required String address,
    required bool isOwner,
    required bool isDefault,
  }) => _transport.request(
    endpoint,
    'createMyRecipient',
    params: {
      'element': {
        'recipientType': recipientType,
        'isOwner': isOwner,
        'isDefault': isDefault,
        'address': address,
      },
    },
    read: (result) => parseMyRecipient(_element(result)),
  );

  /// Updates the recipient [recipientId]. A null [address] or [isDefault] is
  /// not sent.
  Future<Result<MyRecipient, BbxFailure>> updateMyRecipient({
    required String recipientId,
    required String recipientType,
    String? address,
    bool? isDefault,
    bool isOwner = true,
  }) => _transport.request(
    endpoint,
    'updateMyRecipient',
    params: {
      'element': {
        'recipientId': recipientId,
        'recipientType': recipientType,
        'isOwner': isOwner,
        'address': ?address,
        'isDefault': ?isDefault,
      },
    },
    read: (result) => parseMyRecipient(_element(result)),
  );

  /// Creates a fiat recipient.
  Future<Result<FiatRecipient, BbxFailure>> createRecipientFiat(
    NewFiatRecipient recipient,
  ) => _transport.request(
    endpoint,
    'createRecipientFiat',
    params: {'element': newFiatRecipientToJson(recipient)},
    headers: _v2,
    read: (result) => parseFiatRecipient(_element(result)),
  );

  /// Sets the email and the security question and answer of the Interac
  /// recipient [recipientId]. A null question or answer is sent as null.
  Future<Result<void, BbxFailure>> updateInteracSecurityDetails({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
  }) => _transport.request(
    endpoint,
    'updateMyRecipient',
    params: {
      'element': {
        'recipientId': recipientId,
        'recipientType': 'OUT_INTERAC_EMAIL',
        'email': email,
        'securityQuestion': securityQuestion,
        'securityAnswer': securityAnswer,
      },
    },
    headers: _v2,
    read: (_) {},
  );

  /// One page of the user's fiat recipients. Each filter is sent only when
  /// given, and no filters at all when none is.
  Future<Result<FiatRecipientPage, BbxFailure>> listRecipientsFiat({
    int page = 1,
    int pageSize = 50,
    List<String>? recipientTypeFiat,
    bool? isOwner,
    String? search,
  }) => _listRecipients(
    'listRecipientsFiat',
    page: page,
    pageSize: pageSize,
    recipientTypeFiat: recipientTypeFiat,
    isOwner: isOwner,
    search: search,
  );

  /// Like [listRecipientsFiat], over all of the user's recipients.
  Future<Result<FiatRecipientPage, BbxFailure>> listRecipients({
    int page = 1,
    int pageSize = 50,
    List<String>? recipientTypeFiat,
    bool? isOwner,
    String? search,
  }) => _listRecipients(
    'listRecipients',
    page: page,
    pageSize: pageSize,
    recipientTypeFiat: recipientTypeFiat,
    isOwner: isOwner,
    search: search,
  );

  /// The name of the owner of the SINPE Móvil [phoneNumber].
  Future<Result<String, BbxFailure>> checkSinpe({
    required String phoneNumber,
  }) => _transport.request(
    endpoint,
    'checkSinpe',
    params: {'phoneNumber': phoneNumber},
    read: (result) => read<String>(_result(result)['ownerName'], 'ownerName'),
  );

  /// The Canadian billers that match [search]. A missing element list is
  /// empty.
  Future<Result<CadBillerSearch, BbxFailure>> listAplBillers({
    required String search,
  }) => _transport.request(
    endpoint,
    'listAplBillers',
    params: {
      'filters': {'search': search},
    },
    read: (result) {
      final (billers, skipped) = _lenientList(
        _result(result)['elements'],
        parseCadBiller,
      );
      return CadBillerSearch(billers: billers, skippedElements: skipped);
    },
  );

  /// The user's funding instructions for the incoming payment processor
  /// [paymentProcessorCode], e.g. `IN_CAD_EMAIL_TRANSFER_APL`.
  ///
  /// The request also carries `bankCode`, `amount` and `callbackUrl` as
  /// null, like the app always sent them.
  Future<Result<PaymentProcessorDetails, BbxFailure>>
  getUserPaymentProcessorCode(String paymentProcessorCode) =>
      _transport.request(
        endpoint,
        'getUserPaymentProcessorCode',
        params: {
          'paymentProcessorCode': paymentProcessorCode,
          'bankCode': null,
          'amount': null,
          'callbackUrl': null,
        },
        read: (result) => parsePaymentProcessorDetails(_result(result)),
      );

  /// The banks of the country [countryCode] (lowercase ISO 3166-1 alpha-2).
  /// A missing element list is empty.
  Future<Result<InstitutionList, BbxFailure>> listInstitutionCodes({
    required String countryCode,
  }) => _transport.request(
    endpoint,
    'listInstitutionCodes',
    params: {'countryCode': countryCode},
    read: (result) {
      final (institutions, skipped) = _lenientList(
        _result(result)['elements'],
        parseInstitution,
      );
      return InstitutionList(
        institutions: institutions,
        skippedElements: skipped,
      );
    },
  );

  /// The user's virtual IBAN, or null when they have none.
  Future<Result<VirtualIban?, BbxFailure>> findVirtualIban() =>
      _transport.request(
        endpoint,
        'listRecipientsFiat',
        params: {
          'paginator': {'page': 1, 'pageSize': 1},
          'filters': {
            'recipientTypeFiat': ['SEPA_EUR_VIRTUAL_ACCOUNT'],
            'isOwner': true,
          },
        },
        headers: _v2,
        read: (result) {
          final elements = read<List<dynamic>?>(
            read<Map<String, dynamic>?>(result, 'result')?['elements'],
            'elements',
          );
          if (elements == null || elements.isEmpty) return null;
          return parseVirtualIban(
            read<Map<String, dynamic>>(elements.first, 'elements'),
          );
        },
      );

  /// Creates the user's virtual IBAN.
  Future<Result<VirtualIban, BbxFailure>> createVirtualIban() =>
      _transport.request(
        endpoint,
        'createMyRecipient',
        params: {
          'element': {'recipientType': 'FR_VIRTUAL_ACCOUNT', 'isOwner': true},
        },
        read: (result) => parseVirtualIban(_element(result)),
      );

  /// Creates or refreshes the virtual payee of the SEPA recipient
  /// [recipientId].
  Future<Result<SepaVirtualPayee, BbxFailure>> activateSepaVirtualPayee(
    String recipientId,
  ) => _transport.request(
    endpoint,
    'activateSepaVirtualPayee',
    params: {'recipientId': recipientId},
    headers: _v2,
    read: (result) => parseSepaVirtualPayee(_element(result)),
  );

  /// One page of the virtual payees of the user's SEPA recipients. A missing
  /// element list is empty.
  Future<Result<SepaVirtualPayeePage, BbxFailure>> listSepaVirtualPayees({
    required int page,
    required int pageSize,
  }) => _transport.request(
    endpoint,
    'listRecipientsFiat',
    params: {
      'paginator': {'page': page, 'pageSize': pageSize},
      'filters': {
        'recipientTypeFiat': ['SEPA_EUR'],
      },
    },
    headers: _v2,
    read: (result) {
      final element = _result(result);
      return SepaVirtualPayeePage(
        payees: readList(
          element['elements'],
          'elements',
          parseSepaVirtualPayee,
        ),
        totalElements: read<num>(element['totalElements'], 'totalElements'),
      );
    },
  );

  Future<Result<FiatRecipientPage, BbxFailure>> _listRecipients(
    String method, {
    required int page,
    required int pageSize,
    required List<String>? recipientTypeFiat,
    required bool? isOwner,
    required String? search,
  }) {
    final filters = {
      'recipientTypeFiat': ?recipientTypeFiat,
      'isOwner': ?isOwner,
      'search': ?search,
    };
    return _transport.request(
      endpoint,
      method,
      params: {
        'paginator': {'page': page, 'pageSize': pageSize},
        if (filters.isNotEmpty) 'filters': filters,
      },
      headers: _v2,
      read: (result) {
        final element = _result(result);
        final totalElements = read<num>(
          element['totalElements'],
          'totalElements',
        );
        final (recipients, skipped) = _lenientList(
          element['elements'],
          parseFiatRecipient,
        );
        return FiatRecipientPage(
          totalElements: totalElements,
          recipients: recipients,
          skippedElements: skipped,
        );
      },
    );
  }

  static Map<String, dynamic> _result(Object? result) =>
      read<Map<String, dynamic>>(result, 'result');

  static Map<String, dynamic> _element(Object? result) =>
      read<Map<String, dynamic>>(_result(result)['element'], 'element');

  /// Reads an optional array, leaving out the elements that are not valid.
  static (List<T>, int) _lenientList<T>(
    Object? value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final elements = read<List<dynamic>?>(value, 'elements') ?? const [];
    final parsed = <T>[];
    for (final element in elements) {
      if (element is! Map<String, dynamic>) continue;
      try {
        parsed.add(fromJson(element));
      } on BbxFormatException {
        continue;
      }
    }
    return (parsed, elements.length - parsed.length);
  }
}
