import 'dart:async';

import 'package:bb_mobile/features/swap/data/models/order_swap_model.dart';
import 'package:bb_mobile/features/swap/data/models/order_swap_quote_model.dart';
import 'package:bb_mobile/features/swap/data/order_swap_amount_codec.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:dio/dio.dart';

class ExchangePublicApiDatasource {
  final Dio _dio;
  int _requestId = 0;
  Future<void> _requestQueue = Future.value();

  ExchangePublicApiDatasource(this._dio);

  Future<OrderSwapQuoteModel> getBestSwapOption({
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
  }) async {
    final result = await _rpc(
      method: 'getBestSwapOption',
      params: {
        'amount': double.parse(orderSwapSatsToAmount(amountSat)),
        'isInAmountFixed': isInAmountFixed,
        'inNetwork': inNetwork.apiName,
        'outNetwork': outNetwork.apiName,
      },
    );
    return OrderSwapQuoteModel.fromJson(result);
  }

  Future<OrderSwapModel> createOrderSwap({
    String? requestId,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
    required String destinationAddress,
    required String? fallbackAddress,
  }) async {
    final params = {
      'amount': double.parse(orderSwapSatsToAmount(amountSat)),
      'isInAmountFixed': isInAmountFixed,
      'inNetwork': inNetwork.apiName,
      'outNetwork': outNetwork.apiName,
      'destinationAddress': destinationAddress,
      'fallbackAddress': ?fallbackAddress,
    };
    final result = await _rpc(
      requestId: requestId,
      method: 'createOrderSwap',
      params: params,
    );
    return OrderSwapModel.fromJson(result);
  }

  Future<OrderSwapModel> getOrderSwapSummary(String orderId) async {
    final result = await _rpc(
      method: 'getOrderSwapSummary',
      params: {'orderId': orderId},
    );
    return OrderSwapModel.fromJson(result);
  }

  Future<Map<String, dynamic>> _rpc({
    String? requestId,
    required String method,
    required Map<String, dynamic> params,
  }) async {
    final effectiveRequestId = requestId ?? _nextRequestId();
    final previousRequest = _requestQueue;
    final requestCompleted = Completer<void>();
    _requestQueue = requestCompleted.future;
    await previousRequest;
    try {
      return await _sendRpc(
        requestId: effectiveRequestId,
        method: method,
        params: params,
      );
    } finally {
      requestCompleted.complete();
    }
  }

  Future<Map<String, dynamic>> _sendRpc({
    required String requestId,
    required String method,
    required Map<String, dynamic> params,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '',
        data: {
          'jsonrpc': '2.0',
          'id': requestId,
          'method': method,
          'params': params,
        },
        options: Options(validateStatus: (_) => true),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw ExchangeTimeoutException(error.message);
      }
      throw ExchangeNetworkException(error.message);
    }

    if (response.statusCode == 429) {
      final retryAfter = int.tryParse(
        response.headers.value('retry-after') ?? '',
      );
      throw ExchangeRateLimitException(retryAfterSeconds: retryAfter);
    }
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw ExchangeNetworkException('HTTP ${response.statusCode}');
    }
    final body = response.data;
    if (body is! Map) {
      throw const ExchangeResponseException('Response is not JSON');
    }
    final json = Map<String, dynamic>.from(body);
    if (json['id']?.toString() != requestId) {
      throw const ExchangeResponseException('Mismatched RPC response id');
    }
    final error = json['error'];
    if (error is Map) {
      throw ExchangeRpcException.fromJson(Map<String, dynamic>.from(error));
    }
    final result = json['result'];
    if (result is! Map) {
      throw const ExchangeResponseException('Missing RPC result');
    }
    return Map<String, dynamic>.from(result);
  }

  String _nextRequestId() =>
      'mobile-${DateTime.now().microsecondsSinceEpoch}-${_requestId++}';
}

sealed class ExchangeDatasourceException implements Exception {
  final String? logMessage;

  const ExchangeDatasourceException([this.logMessage]);
}

final class ExchangeNetworkException extends ExchangeDatasourceException {
  const ExchangeNetworkException([super.logMessage]);
}

final class ExchangeTimeoutException extends ExchangeDatasourceException {
  const ExchangeTimeoutException([super.logMessage]);
}

final class ExchangeResponseException extends ExchangeDatasourceException {
  const ExchangeResponseException([super.logMessage]);
}

final class ExchangeRateLimitException extends ExchangeDatasourceException {
  final int? retryAfterSeconds;

  const ExchangeRateLimitException({this.retryAfterSeconds});
}

final class ExchangeRpcException extends ExchangeDatasourceException {
  final int? rpcCode;
  final String? apiCode;
  final String? field;
  final String? fieldCode;
  final String? limit;
  final String? limitOperator;

  const ExchangeRpcException({
    this.rpcCode,
    this.apiCode,
    this.field,
    this.fieldCode,
    this.limit,
    this.limitOperator,
    String? logMessage,
  }) : super(logMessage);

  factory ExchangeRpcException.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final dataMap = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    final apiErrorValue = dataMap['apiError'];
    final apiError = apiErrorValue is Map
        ? Map<String, dynamic>.from(apiErrorValue)
        : const <String, dynamic>{};
    final fieldsValue = apiError['fields'] ?? dataMap['errors'];
    final fields = fieldsValue is Map
        ? Map<String, dynamic>.from(fieldsValue)
        : const <String, dynamic>{};
    final messageDataValue = apiError['messageData'];
    final messageData = messageDataValue is Map
        ? Map<String, dynamic>.from(messageDataValue)
        : const <String, dynamic>{};
    final reasonValue = apiError['reason'];
    final reason = reasonValue is Map
        ? Map<String, dynamic>.from(reasonValue)
        : const <String, dynamic>{};
    final reasonFieldsValue = reason['fields'];
    final reasonFields = reasonFieldsValue is List
        ? reasonFieldsValue.whereType<Map>().map(Map<String, dynamic>.from)
        : const Iterable<Map<String, dynamic>>.empty();
    final reasonField = reasonFields.firstOrNull;
    return ExchangeRpcException(
      rpcCode: json['code'] as int?,
      apiCode: apiError['code'] as String?,
      field: fields.keys.firstOrNull ?? reasonField?['fieldName'] as String?,
      fieldCode: reasonField?['code'] as String?,
      limit: messageData['limit']?.toString(),
      limitOperator: messageData['operator'] as String?,
      logMessage: json['message']?.toString(),
    );
  }
}
