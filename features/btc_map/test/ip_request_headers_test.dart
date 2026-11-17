import 'dart:convert';
import 'dart:io';

import 'package:btc_map/src/data/ip_map_location_repository.dart';
import 'package:btc_map/src/domain/bull_map_failure.dart';
import 'package:btc_map/src/domain/entities/geo_point.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test(
    'the actual HTTP request contains only generic transport headers',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final request = server.first.timeout(const Duration(seconds: 5));
      final client = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              // Keep this transport check offline; all other production options apply.
              options.path = 'http://127.0.0.1:${server.port}/';
              handler.next(options);
            },
          ),
        );
      final lookup = IpMapLocationRepository(createClient: () => client)
          .locate();
      final received = await request;
      final headers = <String>[];
      received.headers.forEach((name, _) => headers.add(name));
      received.response.headers.contentType = ContentType.json;
      received.response.write(
        jsonEncode({'success': true, 'latitude': 1, 'longitude': 2}),
      );
      await received.response.close();
      expect(await lookup, isA<Ok<GeoPoint, BullMapFailure>>());
      expect(
        headers.toSet().difference({'host', 'accept-encoding', 'connection'}),
        isEmpty,
      );
      expect(received.uri.queryParameters, {
        'fields': 'success,latitude,longitude',
      });
    },
  );
}
