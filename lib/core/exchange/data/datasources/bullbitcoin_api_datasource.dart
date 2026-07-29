import 'dart:convert' show jsonEncode;
import 'dart:math' show pow;

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/data/models/dca_model.dart';
import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:bb_mobile/core/exchange/data/models/user_preference_payload_model.dart';
import 'package:bb_mobile/core/exchange/data/models/user_summary_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:dio/dio.dart';

abstract class BitcoinPriceDatasource {
  Future<List<String>> get availableCurrencies;
  Future<double> getPrice(String currencyCode);
}

class BullbitcoinApiDatasource implements BitcoinPriceDatasource {
  final Dio _http;
  final _pricePath = '/public/price';
  final _usersPath = '/ak/api-users';
  final _ordersPath = '/ak/api-orders';
  final _orderTriggerPath = '/ak/api-ordertrigger';
  final _recipientsPath = '/ak/api-recipients';
  final _kycPath = '/ak/api-kyc';
  final _messagesPath = '/ak/api-commcenter';

  BullbitcoinApiDatasource({required Dio bullbitcoinApiHttpClient})
    : _http = bullbitcoinApiHttpClient;

  @override
  Future<List<String>> get availableCurrencies async {
    // TODO: fetch the actual list of currencies from the api
    return CurrencyConstants.supportedFiat;
  }

  @override
  Future<double> getPrice(String currencyCode) async {
    try {
      final resp = await _http.post(
        _pricePath,
        // TODO: Create a model for this request data
        data: {
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'getRate',
          'params': {
            'element': {
              'fromCurrency': 'BTC',
              'toCurrency': currencyCode.toUpperCase(),
            },
          },
        },
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        log.warning('Pricer error');
        return 0.0;
      }
      // Parse the response data correctly
      final data = resp.data as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>;
      final element = result['element'] as Map<String, dynamic>;

      // Extract price and precision
      final price = (element['indexPrice'] as num).toDouble();
      final precision = element['precision'] as int? ?? 2;

      // Convert price based on precision (e.g., if price is 11751892 and precision is 2, actual price is 117518.92)
      final rate = price / pow(10, precision);

      return rate;
    } catch (e) {
      log.warning('Pricer error', error: e);
      return 0.0;
    }
  }

  Future<void> registerResponsibilityConsent(String apiKey) async {
    try {
      final resp = await _http.post(
        _usersPath,
        data: {
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'registerResponsibilityConsent',
          'params': {},
        },
        options: Options(headers: {'X-API-Key': apiKey}),
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        throw 'Unable to register scam warning consent';
      }

      final result = resp.data['result'] as Map<String, dynamic>?;
      if (result == null || result['success'] != true) {
        throw 'Unexpected response from registerResponsibilityConsent';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<UserSummaryModel?> getUserSummary(String apiKey) async {
    try {
      final resp = await _http.post(
        _usersPath,
        data: {
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'getUserSummary',
          'params': {},
        },
        options: Options(headers: {'X-API-Key': apiKey}),
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        throw 'Unable to fetch user summary from Bull Bitcoin API';
      }

      final result = resp.data['result'];
      if (result == null) {
        return null;
      }

      final userSummary = UserSummaryModel.fromJson(
        result as Map<String, dynamic>,
      );

      return userSummary;
    } catch (e) {
      rethrow;
    }
  }

  /// Exactly one of [address] and [bip21URI] is sent: they are mutually
  /// exclusive server-side, and the backend extracts the payout address from the
  /// URI when it is given. A payjoin buy therefore has to pass [bip21URI], and
  /// there is no endpoint to swap one for the other afterwards.
  Future<OrderModel> createBuyOrder({
    required String apiKey,
    required FiatCurrency fiatCurrency,
    required OrderAmount orderAmount,
    required OrderBitcoinNetwork network,
    required bool isOwner,
    String? address,
    String? bip21URI,
  }) async {
    assert(
      (address == null) != (bip21URI == null),
      'createOrderBuy takes an address or a bip21URI, never both and never '
      'neither',
    );
    final params = {
      'fiatCurrency': fiatCurrency.code,
      'network': network.value,
      'isOwner': isOwner,
      if (bip21URI != null) 'bip21URI': bip21URI else 'address': address,
    };

    if (orderAmount.isFiat) {
      params['fiatAmount'] = orderAmount.amount;
    } else if (orderAmount.isBitcoin) {
      params['bitcoinAmount'] = orderAmount.amount;
    }

    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'createOrderBuy',
        'params': params,
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    final statusCode = resp.statusCode;
    final error = resp.data['error'];
    if (statusCode != 200) throw Exception('Failed to create order');
    if (error != null) {
      _throwOrderApiError(error, 'Failed to create buy order');
    }
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<OrderModel> confirmOrder({
    required String apiKey,
    required String orderId,
  }) async {
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'confirmOrderSummary',
        'params': {'orderId': orderId},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) throw Exception('Failed to confirm order');
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<OrderModel> getOrderSummary({
    required String apiKey,
    required String orderId,
  }) async {
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'getOrderSummary',
        'params': {'orderId': orderId},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );

    if (resp.statusCode != 200) throw Exception('Failed to get order summary');
    return OrderModel.fromJson(
      (resp.data['result']['element'] ?? resp.data['result'])
          as Map<String, dynamic>,
    );
  }

  Future<List<OrderModel>> listOrderSummaries({required String apiKey}) async {
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'listOrderSummaries',
        'params': {
          "sortBy": {"id": "createdAt", "sort": "desc"},
          "paginator": {"page": 1, "pageSize": 50},
        },
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to list order summaries');
    }
    final elements = resp.data['result']['elements'] as List<dynamic>?;
    if (elements == null) return [];
    return elements
        .map((e) {
          // Parse each order on its own so one malformed element doesn't cost
          // the user their whole order history. Nulls are filtered out below.
          try {
            return OrderModel.fromJson(e as Map<String, dynamic>);
          } catch (err, stackTrace) {
            log.severe(
              message: 'Error parsing order element',
              error: err,
              trace: stackTrace,
            );
            return null;
          }
        })
        .whereType<OrderModel>()
        .toList();
  }

  Future<OrderModel> refreshOrder({
    required String apiKey,
    required String orderId,
  }) async {
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'refreshOrderSummary',
        'params': {'orderId': orderId},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to refresh order summary');
    }
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<OrderModel> dequeueAndPay({
    required String apiKey,
    required String orderId,
  }) async {
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'unbatchAndExpressOrder',
        'params': {'orderId': orderId},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to refresh order summary');
    }
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<void> saveUserPreference({
    required String apiKey,
    required UserPreferencePayloadModel params,
  }) async {
    try {
      final resp = await _http.post(
        _usersPath,
        data: {
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'saveUserPreferences',
          'params': {'userPreferences': params.toMap()},
        },
        options: Options(headers: {'X-API-Key': apiKey}),
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        throw Exception('Failed to save user preferences');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// [usePayjoin] asks the exchange to receive the payin through payjoin, which
  /// makes it publish a `bip21URI` on the order. Only meaningful on
  /// [OrderBitcoinNetwork.bitcoin]. Omitted rather than sent as false so a
  /// backend without the flag is unaffected.
  Future<OrderModel> createSellOrder({
    required String apiKey,
    required FiatCurrency fiatCurrency,
    required OrderAmount orderAmount,
    required OrderBitcoinNetwork network,
    bool usePayjoin = false,
  }) async {
    final params = <String, dynamic>{
      'fiatCurrency': fiatCurrency.code,
      'bitcoinNetwork': network.value,
      if (usePayjoin) 'usePayjoin': true,
    };

    if (orderAmount.isFiat) {
      params['fiatAmount'] = orderAmount.amount;
    } else if (orderAmount.isBitcoin) {
      params['bitcoinAmount'] = orderAmount.amount;
    }

    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'sellToBalance',
        'params': params,
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    final statusCode = resp.statusCode;
    final error = resp.data['error'];
    if (statusCode != 200) throw Exception('Failed to create sell order');
    if (error != null) {
      _throwOrderApiError(error, 'Failed to create sell order');
    }
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  /// See [createSellOrder] for [usePayjoin]; a payment is a sell to a recipient
  /// and the flag behaves identically.
  Future<OrderModel> createPayOrder({
    required String apiKey,
    required OrderAmount orderAmount,
    required String recipientId,
    required OrderBitcoinNetwork network,
    String? paymentDescription,
    bool usePayjoin = false,
  }) async {
    final params = <String, dynamic>{
      'recipientId': recipientId,
      'bitcoinNetwork': network.value,
      if (usePayjoin) 'usePayjoin': true,
    };

    if (orderAmount.isFiat) {
      params['fiatAmount'] = orderAmount.amount;
    } else if (orderAmount.isBitcoin) {
      params['bitcoinAmount'] = orderAmount.amount;
    }

    if (paymentDescription != null && paymentDescription.isNotEmpty) {
      params['paymentDescription'] = paymentDescription;
    }

    final requestData = {
      'jsonrpc': '2.0',
      'id': '0',
      'method': 'sellToRecipient',
      'params': params,
    };

    final resp = await _http.post(
      _ordersPath,
      data: requestData,
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    final statusCode = resp.statusCode;
    final error = resp.data['error'];
    if (statusCode != 200) {
      throw Exception('Failed to create sell to recipient order');
    }
    if (error != null) {
      _throwOrderApiError(error, 'Failed to create sell to recipient order');
    }

    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<OrderModel> createWithdrawalOrder({
    required String apiKey,
    required double fiatAmount,
    required String recipientId,
    bool isETransfer = false,
  }) async {
    /**
     *   "paymentProcessorData": {
    "securityQuestion": "What is your favorite color?",
    "securityAnswer": "Blue"
  }
  if e-transfer fails with 400 for security Q/A
     */
    final params = <String, dynamic>{
      'fiatAmount': fiatAmount,
      'recipientId': recipientId,
    };

    if (isETransfer) {
      params['paymentProcessorData'] = {
        'securityQuestion': 'What is your favorite color?',
        'securityAnswer': 'Orange',
      };
    }
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'createWithdrawalOrder',
        'params': params,
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    final statusCode = resp.statusCode;
    final error = resp.data['error'];
    if (statusCode != 200) throw Exception('Failed to create withdrawal order');
    if (error != null) {
      _throwOrderApiError(error, 'Failed to create withdrawal order');
    }
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<DcaModel> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required DcaNetwork network,
    required String address,
    required String apiKey,
  }) async {
    final data = {
      'jsonrpc': '2.0',
      'id': '1',
      'method': 'createDCA',
      'params': {
        'element': {
          'amountStr': amount.toString(),
          'currencyCode': currency.code,
          'recurringFrequency': switch (frequency) {
            DcaBuyFrequency.hourly => 'HOURLY',
            DcaBuyFrequency.daily => 'DAILY',
            DcaBuyFrequency.weekly => 'WEEKLY',
            DcaBuyFrequency.monthly => 'MONTHLY',
          },
          'recipientType': switch (network) {
            DcaNetwork.bitcoin => 'OUT_BITCOIN_ADDRESS',
            DcaNetwork.lightning => 'OUT_LIGHTNING_ADDRESS',
            DcaNetwork.liquid => 'OUT_LIQUID_ADDRESS',
          },
          'address': address,
        },
      },
    };
    final resp = await _http.post(
      _orderTriggerPath,
      data: data,
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to create DCA');
    }
    if (resp.data['error'] != null) {
      final error = resp.data['error'];
      final message = error['message'];
      throw Exception('Failed to create DCA: $message');
    }
    return DcaModel.fromJson(
      resp.data['result']['element'] as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> getBuyLimits({required String apiKey}) async {
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'getBuyLimits',
        'params': {},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to get buy limits');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw Exception('Failed to get buy limits: $error');
    }

    return resp.data['result'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSellLimits({required String apiKey}) async {
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'getSellLimits',
        'params': {},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to get sell limits');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw Exception('Failed to get sell limits: $error');
    }

    return resp.data['result'] as Map<String, dynamic>;
  }

  // ==================== Recipients API ====================

  /// List recipients with optional filters for default wallets
  Future<List<Map<String, dynamic>>> listMyRecipients({
    required String apiKey,
    List<String>? recipientTypes,
    bool? isDefault,
  }) async {
    final filters = <String, dynamic>{};
    if (recipientTypes != null) {
      filters['recipientTypes'] = recipientTypes;
    }
    if (isDefault != null) {
      filters['isDefault'] = isDefault;
    }

    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'listMyRecipients',
        'params': {'filters': filters},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to list recipients');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw Exception('Failed to list recipients: $error');
    }

    final elements = resp.data['result']['elements'] as List<dynamic>?;
    if (elements == null) return [];
    return elements.cast<Map<String, dynamic>>();
  }

  /// Create a new recipient (default wallet)
  Future<Map<String, dynamic>> createMyRecipient({
    required String apiKey,
    required String recipientType,
    required String address,
    required bool isOwner,
    required bool isDefault,
  }) async {
    final recipientDetails = _buildRecipientDetails(recipientType, address);

    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'createMyRecipient',
        'params': {
          'element': {
            'recipientType': recipientType,
            'isOwner': isOwner,
            'isDefault': isDefault,
            ...recipientDetails,
          },
        },
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to create recipient');
    }

    final error = resp.data['error'];
    if (error != null) {
      final message = error['message'] ?? 'Unknown error';
      throw Exception('Failed to create recipient: $message');
    }

    return resp.data['result']['element'] as Map<String, dynamic>;
  }

  /// Update an existing recipient
  Future<Map<String, dynamic>> updateMyRecipient({
    required String apiKey,
    required String recipientId,
    required String recipientType,
    String? address,
    bool? isDefault,
    bool isOwner = true,
  }) async {
    final element = <String, dynamic>{
      'recipientId': recipientId,
      'recipientType': recipientType,
      'isOwner': isOwner,
    };

    if (address != null) {
      // For updates, use the generic 'address' field (not type-specific fields)
      element['address'] = address;
    }
    if (isDefault != null) {
      element['isDefault'] = isDefault;
    }

    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'updateMyRecipient',
        'params': {'element': element},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to update recipient');
    }

    final error = resp.data['error'];
    if (error != null) {
      final message = error['message'] ?? 'Unknown error';
      throw Exception('Failed to update recipient: $message');
    }

    return resp.data['result']['element'] as Map<String, dynamic>;
  }

  Map<String, dynamic> _buildRecipientDetails(
    String recipientType,
    String address,
  ) {
    // For OUT_BITCOIN_ADDRESS, OUT_LIGHTNING_ADDRESS, OUT_LIQUID_ADDRESS,
    // the API expects the generic 'address' field, not type-specific fields
    switch (recipientType) {
      case 'OUT_BITCOIN_ADDRESS':
      case 'OUT_LIGHTNING_ADDRESS':
      case 'OUT_LIQUID_ADDRESS':
        return {'address': address};
      default:
        return {'address': address};
    }
  }

  // ==================== Order Stats API ====================

  /// Get order statistics for the user
  Future<Map<String, dynamic>> getOrderStats({required String apiKey}) async {
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'getOrderStats',
        'params': {},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to get order stats');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw Exception('Failed to get order stats: $error');
    }

    return resp.data['result']['element'] as Map<String, dynamic>;
  }

  // ==================== KYC Upload API ====================

  /// Upload a KYC document file using multipart form (same as BB-Exchange)
  Future<void> uploadKycDocument({
    required String apiKey,
    required List<int> fileBytes,
    required String fileName,
    required String docType,
    required String sourceDetail,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'kycIDDocument': jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'createMyKYCIDDocument',
        'params': {
          'element': {'idTypeCode': docType, 'sourceDetail': sourceDetail},
        },
      }),
    });

    final resp = await _http.post(
      '$_kycPath/upload',
      data: formData,
      options: Options(
        headers: {'X-API-Key': apiKey},
        contentType: 'multipart/form-data',
      ),
    );

    if (resp.statusCode != 200) {
      throw Exception('File upload failed with status: ${resp.statusCode}');
    }

    // Check if response data indicates an error condition
    final responseData = resp.data as Map<String, dynamic>?;
    if (responseData != null) {
      // Check for various error indicators in the response
      if (responseData.containsKey('error') ||
          responseData.containsKey('errors') ||
          (responseData.containsKey('result') &&
              responseData['result'] is Map<String, dynamic> &&
              (responseData['result']['error'] != null ||
                  responseData['result']['errors'] != null))) {
        throw Exception('File upload failed: API returned error in response');
      }
    }
  }

  // ==================== Announcements API ====================

  Future<List<Map<String, dynamic>>> listAnnouncements({
    required String apiKey,
  }) async {
    try {
      final resp = await _http.post(
        _messagesPath,
        data: {
          'jsonrpc': '2.0',
          'id': '1',
          'method': 'listAnnouncements',
          'params': {
            'paginator': {'pageSize': 5, 'page': 1},
            'sortBy': {'id': 'updatedAt', 'sort': 'desc'},
          },
        },
        options: Options(headers: {'X-API-Key': apiKey}),
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        throw Exception('Failed to list announcements');
      }

      final error = resp.data['error'];
      if (error != null) {
        throw Exception('Failed to list announcements: $error');
      }

      final result = resp.data['result'] as Map<String, dynamic>?;
      if (result == null) {
        return [];
      }
      final items = result['elements'] as List<dynamic>? ?? [];
      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }
}

const _minLimitOperator = 'GREATER_THAN_OR_EQUAL';
const _maxLimitOperator = 'LESS_THAN_OR_EQUAL';

/// A single limit that the api rejected an order against.
class _OrderLimit {
  final double amount;
  final String currency;
  final String conditionalOperator;

  const _OrderLimit({
    required this.amount,
    required this.currency,
    required this.conditionalOperator,
  });

  /// Returns null for anything that isn't a limit we can act on, so a payload
  /// change on the api side degrades to the generic error instead of throwing
  /// a cast error.
  static _OrderLimit? tryParse(dynamic json) {
    if (json is! Map) return null;
    final rawAmount = json['amount'];
    final amount = switch (rawAmount) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
    final currency = json['currencyCode'];
    final conditionalOperator = json['conditionalOperator'];
    if (amount == null ||
        currency is! String ||
        conditionalOperator is! String) {
      return null;
    }
    return _OrderLimit(
      amount: amount,
      currency: currency,
      conditionalOperator: conditionalOperator,
    );
  }
}

/// Translates a JSON-RPC `error` object from the orders api into a typed
/// exception. Always throws: an error response must never fall through to
/// parsing `result`.
///
/// Two payload shapes are supported. A single rejected payment option carries
/// `data.reason.limit`; when every payment option was rejected the aggregate
/// error carries one structured reason per rejection in `data.reasons`.
///
/// `reasons` is legitimately empty for rejections that produce no structured
/// reason (group-access denial, non-positive amounts), so an empty or absent
/// array has to reach the generic error rather than be treated as a bug. The
/// aggregate also carries a legacy `data.details`, always an array of nulls;
/// it is deliberately never read.
Never _throwOrderApiError(dynamic error, String contextMessage) {
  final errorMap = error is Map ? error : const <dynamic, dynamic>{};
  final data = errorMap['data'];
  final dataMap = data is Map ? data : const <dynamic, dynamic>{};

  final limits = <_OrderLimit>[];
  final reasons = dataMap['reasons'];
  if (reasons is List) {
    for (final reason in reasons) {
      final limit = _OrderLimit.tryParse(
        reason is Map ? reason['limit'] : null,
      );
      if (limit != null) limits.add(limit);
    }
  }
  final singleReason = dataMap['reason'];
  final singleLimit = _OrderLimit.tryParse(
    singleReason is Map ? singleReason['limit'] : null,
  );
  if (singleLimit != null) limits.add(singleLimit);

  final operators = limits.map((l) => l.conditionalOperator).toSet();
  // Amounts are only comparable within one currency, and a single message can
  // only name one limit, so anything mixed falls back to the generic error.
  final currencies = limits.map((l) => l.currency).toSet();
  if (operators.length == 1 && currencies.length == 1) {
    switch (operators.single) {
      case _minLimitOperator:
        // Every option was below its minimum, so the lowest minimum is the
        // amount that unlocks at least one of them.
        final min = limits.reduce((a, b) => a.amount <= b.amount ? a : b);
        throw BullBitcoinApiMinAmountException(
          minAmount: min.amount,
          currency: min.currency,
        );
      case _maxLimitOperator:
        final max = limits.reduce((a, b) => a.amount >= b.amount ? a : b);
        throw BullBitcoinApiMaxAmountException(
          maxAmount: max.amount,
          currency: max.currency,
        );
    }
  }

  final message = errorMap['message'];
  throw Exception('$contextMessage${message is String ? ': $message' : ''}');
}

class BullBitcoinApiMinAmountException extends BullException {
  final double minAmount;
  final String currency;

  BullBitcoinApiMinAmountException({
    required this.minAmount,
    required this.currency,
  }) : super('Minimum amount is $minAmount $currency');
}

class BullBitcoinApiMaxAmountException extends BullException {
  final double maxAmount;
  final String currency;

  BullBitcoinApiMaxAmountException({
    required this.maxAmount,
    required this.currency,
  }) : super('Maximum amount is $maxAmount $currency');
}
