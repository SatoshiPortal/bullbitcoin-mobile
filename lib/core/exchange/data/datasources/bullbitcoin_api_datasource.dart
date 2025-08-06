import 'dart:math' show pow;

import 'package:bb_mobile/core/exchange/data/models/funding_details_model.dart';
import 'package:bb_mobile/core/exchange/data/models/funding_details_request_params_model.dart';
import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:bb_mobile/core/exchange/data/models/recipient_model.dart';
import 'package:bb_mobile/core/exchange/data/models/user_preference_payload_model.dart';
import 'package:bb_mobile/core/exchange/data/models/user_summary_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
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
  final _recipientsPath = '/ak/api-recipients';

  BullbitcoinApiDatasource({required Dio bullbitcoinApiHttpClient})
    : _http = bullbitcoinApiHttpClient;

  @override
  Future<List<String>> get availableCurrencies async {
    // TODO: fetch the actual list of currencies from the api
    return ['USD', 'CAD', 'MXN', 'CRC', 'EUR'];
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
      log.warning(e.toString());
      return 0.0;
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

      final userSummary = UserSummaryModel.fromJson(
        resp.data['result'] as Map<String, dynamic>,
      );

      return userSummary;
    } catch (e) {
      rethrow;
    }
  }

  Future<OrderModel> createBuyOrder({
    required String apiKey,
    required FiatCurrency fiatCurrency,
    required OrderAmount orderAmount,
    required OrderBitcoinNetwork network,
    required bool isOwner,
    required String address,
  }) async {
    final params = {
      'fiatCurrency': fiatCurrency.code,
      'network': network.value,
      'isOwner': isOwner,
      'address': address,
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
      final reason = error['data']['reason'];
      final limitReason = reason['limit'];
      if (limitReason != null) {
        final isBelowLimit =
            limitReason['conditionalOperator'] == 'GREATER_THAN_OR_EQUAL';
        final limitAmount = limitReason['amount'] as String;
        final limitCurrency = limitReason['currencyCode'] as String;
        if (isBelowLimit) {
          throw BullBitcoinApiMinAmountException(
            minAmount: double.parse(limitAmount),
            currency: limitCurrency,
          );
        } else {
          throw BullBitcoinApiMaxAmountException(
            maxAmount: double.parse(limitAmount),
            currency: limitCurrency,
          );
        }
      }
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
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
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

  Future<FundingDetailsModel> getFundingDetails({
    required String apiKey,
    required FundingDetailsRequestParamsModel fundingDetailsRequestParams,
  }) async {
    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'getFundingDetails',
        'params': fundingDetailsRequestParams.toJson(),
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to get funding details');
    }

    return FundingDetailsModel.fromJson(
      resp.data['result']['element']['element'] as Map<String, dynamic>,
    );
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

  Future<OrderModel> createSellOrder({
    required String apiKey,
    required FiatCurrency fiatCurrency,
    required OrderAmount orderAmount,
    required OrderBitcoinNetwork network,
  }) async {
    final params = <String, dynamic>{
      'fiatCurrency': fiatCurrency.code,
      'bitcoinNetwork': network.value,
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
      final reason = error['data']['reason'];
      final limitReason = reason['limit'];
      if (limitReason != null) {
        final isBelowLimit =
            limitReason['conditionalOperator'] == 'GREATER_THAN_OR_EQUAL';
        final limitAmount = limitReason['amount'] as String;
        final limitCurrency = limitReason['currencyCode'] as String;
        if (isBelowLimit) {
          throw BullBitcoinApiMinAmountException(
            minAmount: double.parse(limitAmount),
            currency: limitCurrency,
          );
        } else {
          throw BullBitcoinApiMaxAmountException(
            maxAmount: double.parse(limitAmount),
            currency: limitCurrency,
          );
        }
      }
    }
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<OrderModel> createPayOrder({
    required String apiKey,
    required OrderAmount orderAmount,
    required String recipientId,
    required String paymentProcessor,
    required OrderBitcoinNetwork network,
  }) async {
    final params = <String, dynamic>{
      'recipientId': recipientId,
      'paymentProcessor': paymentProcessor,
      'bitcoinNetwork': network.value,
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
        'method': 'sellToRecipient',
        'params': params,
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    final statusCode = resp.statusCode;
    final error = resp.data['error'];
    if (statusCode != 200) {
      throw Exception('Failed to create sell to recipient order');
    }
    if (error != null) {
      final reason = error['data']['reason'];
      final limitReason = reason['limit'];
      if (limitReason != null) {
        final isBelowLimit =
            limitReason['conditionalOperator'] == 'GREATER_THAN_OR_EQUAL';
        final limitAmount = limitReason['amount'] as String;
        final limitCurrency = limitReason['currencyCode'] as String;
        if (isBelowLimit) {
          throw BullBitcoinApiMinAmountException(
            minAmount: double.parse(limitAmount),
            currency: limitCurrency,
          );
        } else {
          throw BullBitcoinApiMaxAmountException(
            maxAmount: double.parse(limitAmount),
            currency: limitCurrency,
          );
        }
      }
    }
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<OrderModel> createWithdrawalOrder({
    required String apiKey,
    required double fiatAmount,
    required String recipientId,
    required String paymentProcessor,
  }) async {
    final resp = await _http.post(
      _ordersPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'createWithdrawalOrder',
        'params': {
          'fiatAmount': fiatAmount,
          'recipientId': recipientId,
          'paymentProcessor': paymentProcessor,
        },
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    final statusCode = resp.statusCode;
    final error = resp.data['error'];
    if (statusCode != 200) throw Exception('Failed to create withdrawal order');
    if (error != null) {
      final reason = error['data']['reason'];
      final limitReason = reason['limit'];
      if (limitReason != null) {
        final isBelowLimit =
            limitReason['conditionalOperator'] == 'GREATER_THAN_OR_EQUAL';
        final limitAmount = limitReason['amount'] as String;
        final limitCurrency = limitReason['currencyCode'] as String;
        if (isBelowLimit) {
          throw BullBitcoinApiMinAmountException(
            minAmount: double.parse(limitAmount),
            currency: limitCurrency,
          );
        } else {
          throw BullBitcoinApiMaxAmountException(
            maxAmount: double.parse(limitAmount),
            currency: limitCurrency,
          );
        }
      }
    }
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<List<RecipientModel>> listRecipients({required String apiKey}) async {
    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'listRecipients',
        'params': {},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to list recipients');
    }
    final elements = resp.data['result']['elements'] as List<dynamic>?;
    if (elements == null) return [];
    return elements
        .map((e) => RecipientModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecipientModel>> listRecipientsFiat({
    required String apiKey,
  }) async {
    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'listRecipientsFiat',
        'params': {},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to list fiat recipients');
    }
    final elements = resp.data['result']['elements'] as List<dynamic>?;
    if (elements == null) return [];
    return elements
        .map((e) => RecipientModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class BullBitcoinApiMinAmountException implements Exception {
  final double minAmount;
  final String currency;

  BullBitcoinApiMinAmountException({
    required this.minAmount,
    required this.currency,
  });
}

class BullBitcoinApiMaxAmountException implements Exception {
  final double maxAmount;
  final String currency;

  BullBitcoinApiMaxAmountException({
    required this.maxAmount,
    required this.currency,
  });
}
