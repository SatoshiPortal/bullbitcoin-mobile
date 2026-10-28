import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:dio/dio.dart' as dio;

class FakeHttpStatus {
  final int status;
  final Object body;

  const FakeHttpStatus(this.status, [this.body = const <String, Object>{}]);
}

/// Answers each request with the next of [answers]: a JSON body, a
/// [FakeHttpStatus], or a [dio.DioExceptionType] to fail with. Records each
/// request body.
class FakeBbxApi implements dio.HttpClientAdapter {
  final List<Object> answers = [];
  final List<Map<String, dynamic>> payloads = [];

  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    payloads.add(options.data as Map<String, dynamic>);
    final answer = answers.removeAt(0);
    if (answer is dio.DioExceptionType) {
      throw dio.DioException(requestOptions: options, type: answer);
    }
    final (status, body) = switch (answer) {
      FakeHttpStatus(:final status, :final body) => (status, body),
      _ => (200, answer),
    };
    return dio.ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        dio.Headers.contentTypeHeader: [dio.Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  BbxApiDatasource datasource() {
    final client = bbx.BBApiClient(
      bbx.ApiConfig('https://api.test', clientSource: 'Test App'),
      initialDio: dio.Dio()..httpClientAdapter = this,
    );
    return BbxApiDatasource(bbx.BbxApi(client.apiConfig, client: client));
  }
}

Map<String, dynamic> rpcResult(Map<String, dynamic> result) => {
  'jsonrpc': '2.0',
  'id': '1',
  'result': result,
};

Map<String, dynamic> rpcPage(List<Map<String, dynamic>> elements, int total) =>
    rpcResult({'elements': elements, 'totalElements': total});

Map<String, dynamic> rpcElement(Map<String, dynamic> element) =>
    rpcResult({'element': element});

Map<String, dynamic> rpcRefusal(String code) => {
  'jsonrpc': '2.0',
  'id': '1',
  'error': {
    'code': -32602,
    'message': 'Invalid params',
    'data': {
      'apiError': {'code': code, 'message': 'refused'},
    },
  },
};
