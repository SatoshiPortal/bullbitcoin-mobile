import 'dart:io';
import 'dart:typed_data';

import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a relay redirect never sends the client directly to a directory',
    () async {
      final directory = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final relay = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final directoryRequests = <String>[];
      directory.listen((request) async {
        directoryRequests.add(request.method);
        request.response.add([1, 2, 3]);
        await request.response.close();
      });
      relay.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = HttpStatus.seeOther;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://127.0.0.1:${directory.port}/session',
        );
        await request.response.close();
      });
      final dio = Dio();
      DioException? failure;
      try {
        try {
          await PdkPayjoinDatasource.postBytes(
            dio,
            'http://127.0.0.1:${relay.port}/ohttp',
            Uint8List.fromList([1]),
            'message/ohttp-req',
          );
        } on DioException catch (error) {
          failure = error;
        }
        expect(
          directoryRequests,
          isEmpty,
          reason:
              'the directory must never see the client IP after a relay redirect',
        );
        expect(
          failure,
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.badResponse,
          ),
        );
      } finally {
        dio.close(force: true);
        await relay.close(force: true);
        await directory.close(force: true);
      }
    },
  );
}
