import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/recipients/cad_biller.dart';
import 'package:bbx_api/src/recipients/fiat_recipient.dart';
import 'package:bbx_api/src/recipients/institution.dart';
import 'package:bbx_api/src/recipients/my_recipient.dart';
import 'package:bbx_api/src/recipients/new_fiat_recipient.dart';
import 'package:bbx_api/src/recipients/payment_processor_details.dart';
import 'package:bbx_api/src/recipients/virtual_accounts.dart';

/// The `api-recipients` endpoint: payout recipients, the virtual IBAN, SEPA
/// virtual payees and funding instructions.
///
/// The fiat recipient calls ask for version 2 of the API with the
/// `x-api-version` header; the others use the default version.
class RecipientsApi {
  static const endpoint = '/ak/api-recipients';
  static const _v2 = {'x-api-version': '2.0.0'};

  final BbxApiClient _client;

  RecipientsApi(this._client);

  /// The user's recipients, filtered by `recipientType` and `isDefault`
  /// when given. A missing element list is empty.
  Future<List<MyRecipient>> listMyRecipients({
    List<String>? recipientTypes,
    bool? isDefault,
  }) async {
    final result = await _result('listMyRecipients', {
      'filters': {'recipientTypes': ?recipientTypes, 'isDefault': ?isDefault},
    });
    return readList(result['elements'], 'elements', MyRecipient.fromJson);
  }

  /// Creates a recipient of [recipientType] paid to [address].
  Future<MyRecipient> createMyRecipient({
    required String recipientType,
    required String address,
    required bool isOwner,
    required bool isDefault,
  }) async => MyRecipient.fromJson(
    await _element('createMyRecipient', {
      'element': {
        'recipientType': recipientType,
        'isOwner': isOwner,
        'isDefault': isDefault,
        'address': address,
      },
    }),
  );

  /// Updates the recipient [recipientId]. A null [address] or [isDefault] is
  /// not sent.
  Future<MyRecipient> updateMyRecipient({
    required String recipientId,
    required String recipientType,
    String? address,
    bool? isDefault,
    bool isOwner = true,
  }) async => MyRecipient.fromJson(
    await _element('updateMyRecipient', {
      'element': {
        'recipientId': recipientId,
        'recipientType': recipientType,
        'isOwner': isOwner,
        'address': ?address,
        'isDefault': ?isDefault,
      },
    }),
  );

  /// Creates a fiat recipient.
  Future<FiatRecipient> createRecipientFiat(NewFiatRecipient recipient) async =>
      FiatRecipient.fromJson(
        await _element('createRecipientFiat', {
          'element': recipient.toJson(),
        }, headers: _v2),
      );

  /// Sets the email and the security question and answer of the Interac
  /// recipient [recipientId]. A null question or answer is sent as null.
  Future<void> updateInteracSecurityDetails({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
  }) async {
    await _client.call(
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
    );
  }

  /// One page of the user's fiat recipients. Each filter is sent only when
  /// given, and no filters at all when none is.
  Future<FiatRecipientPage> listRecipientsFiat({
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
  Future<FiatRecipientPage> listRecipients({
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
  Future<String> checkSinpe({required String phoneNumber}) async {
    final result = await _result('checkSinpe', {'phoneNumber': phoneNumber});
    return read<String>(result['ownerName'], 'ownerName');
  }

  /// The Canadian billers that match [search]. A missing element list is
  /// empty.
  Future<CadBillerSearch> listAplBillers({required String search}) async {
    final result = await _result('listAplBillers', {
      'filters': {'search': search},
    });
    final (billers, skipped) = _lenientList(
      result['elements'],
      CadBiller.fromJson,
    );
    return CadBillerSearch(billers: billers, skippedElements: skipped);
  }

  /// The user's funding instructions for the incoming payment processor
  /// [paymentProcessorCode], e.g. `IN_CAD_EMAIL_TRANSFER_APL`.
  ///
  /// The request also carries `bankCode`, `amount` and `callbackUrl` as
  /// null, like the app always sent them.
  Future<PaymentProcessorDetails> getUserPaymentProcessorCode(
    String paymentProcessorCode,
  ) async => PaymentProcessorDetails.fromJson(
    await _result('getUserPaymentProcessorCode', {
      'paymentProcessorCode': paymentProcessorCode,
      'bankCode': null,
      'amount': null,
      'callbackUrl': null,
    }),
  );

  /// The banks of the country [countryCode] (lowercase ISO 3166-1 alpha-2).
  /// A missing element list is empty.
  Future<InstitutionList> listInstitutionCodes({
    required String countryCode,
  }) async {
    final result = await _result('listInstitutionCodes', {
      'countryCode': countryCode,
    });
    final (institutions, skipped) = _lenientList(
      result['elements'],
      Institution.fromJson,
    );
    return InstitutionList(
      institutions: institutions,
      skippedElements: skipped,
    );
  }

  /// The user's virtual IBAN, or null when they have none.
  Future<VirtualIban?> findVirtualIban() async {
    final result = read<Map<String, dynamic>?>(
      await _client.call(
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
      ),
      'result',
    );
    final elements = read<List<dynamic>?>(result?['elements'], 'elements');
    if (elements == null || elements.isEmpty) return null;
    return VirtualIban.fromJson(
      read<Map<String, dynamic>>(elements.first, 'elements'),
    );
  }

  /// Creates the user's virtual IBAN.
  Future<VirtualIban> createVirtualIban() async => VirtualIban.fromJson(
    await _element('createMyRecipient', {
      'element': {'recipientType': 'FR_VIRTUAL_ACCOUNT', 'isOwner': true},
    }),
  );

  /// Creates or refreshes the virtual payee of the SEPA recipient
  /// [recipientId].
  Future<SepaVirtualPayee> activateSepaVirtualPayee(String recipientId) async =>
      SepaVirtualPayee.fromJson(
        await _element('activateSepaVirtualPayee', {
          'recipientId': recipientId,
        }, headers: _v2),
      );

  /// One page of the virtual payees of the user's SEPA recipients. A missing
  /// element list is empty.
  Future<SepaVirtualPayeePage> listSepaVirtualPayees({
    required int page,
    required int pageSize,
  }) async {
    final result = await _result('listRecipientsFiat', {
      'paginator': {'page': page, 'pageSize': pageSize},
      'filters': {
        'recipientTypeFiat': ['SEPA_EUR'],
      },
    }, headers: _v2);
    return SepaVirtualPayeePage(
      payees: readList(
        result['elements'],
        'elements',
        SepaVirtualPayee.fromJson,
      ),
      totalElements: read<num>(result['totalElements'], 'totalElements'),
    );
  }

  Future<FiatRecipientPage> _listRecipients(
    String method, {
    required int page,
    required int pageSize,
    required List<String>? recipientTypeFiat,
    required bool? isOwner,
    required String? search,
  }) async {
    final filters = {
      'recipientTypeFiat': ?recipientTypeFiat,
      'isOwner': ?isOwner,
      'search': ?search,
    };
    final result = await _result(method, {
      'paginator': {'page': page, 'pageSize': pageSize},
      if (filters.isNotEmpty) 'filters': filters,
    }, headers: _v2);
    final totalElements = read<num>(result['totalElements'], 'totalElements');
    final (recipients, skipped) = _lenientList(
      result['elements'],
      FiatRecipient.fromJson,
    );
    return FiatRecipientPage(
      totalElements: totalElements,
      recipients: recipients,
      skippedElements: skipped,
    );
  }

  Future<Map<String, dynamic>> _result(
    String method,
    Map<String, Object?> params, {
    Map<String, Object?>? headers,
  }) async => read<Map<String, dynamic>>(
    await _client.call(endpoint, method, params: params, headers: headers),
    'result',
  );

  Future<Map<String, dynamic>> _element(
    String method,
    Map<String, Object?> params, {
    Map<String, Object?>? headers,
  }) async {
    final result = await _result(method, params, headers: headers);
    return read<Map<String, dynamic>>(result['element'], 'element');
  }

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
      } on BbxApiFormatException {
        continue;
      }
    }
    return (parsed, elements.length - parsed.length);
  }
}
