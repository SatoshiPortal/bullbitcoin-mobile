import 'package:bb_mobile/core/exchange/data/services/exchange_clock_offset.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final serverNow = DateTime.utc(2026, 11, 6, 12);
  final deadline = DateTime.utc(2026, 11, 6, 12, 5);

  group('observe', () {
    test('an offset within tolerance counts as none', () {
      final offset = ExchangeClockOffset()
        ..observe(
          serverTime: serverNow,
          deviceTime: serverNow.add(const Duration(seconds: 10)),
        );

      expect(offset.offset, Duration.zero);
      expect(offset.toDeviceClock(deadline), deadline);
    });

    test('a device clock running ahead moves the deadline later', () {
      final offset = ExchangeClockOffset()
        ..observe(
          serverTime: serverNow,
          deviceTime: serverNow.add(const Duration(minutes: 30)),
        );

      expect(offset.offset, const Duration(minutes: -30));
      expect(
        offset.toDeviceClock(deadline),
        deadline.add(const Duration(minutes: 30)),
      );
    });

    test('a device clock running behind moves the deadline earlier', () {
      final offset = ExchangeClockOffset()
        ..observe(
          serverTime: serverNow,
          deviceTime: serverNow.subtract(const Duration(minutes: 30)),
        );

      expect(
        offset.toDeviceClock(deadline),
        deadline.subtract(const Duration(minutes: 30)),
      );
    });

    test('the latest response wins', () {
      final offset = ExchangeClockOffset()
        ..observe(
          serverTime: serverNow,
          deviceTime: serverNow.add(const Duration(minutes: 30)),
        )
        ..observe(serverTime: serverNow, deviceTime: serverNow);

      expect(offset.offset, Duration.zero);
    });
  });

  group('interceptor', () {
    Future<ExchangeClockOffset> respondWith(Map<String, String> headers) async {
      final offset = ExchangeClockOffset();
      final dio = Dio()
        ..interceptors.add(offset.interceptor)
        ..httpClientAdapter = _HeadersAdapter(headers);
      await withClock(
        Clock.fixed(serverNow.add(const Duration(minutes: 30))),
        () => dio.get<String>('https://api.example/'),
      );
      return offset;
    }

    test('reads the Date header of a response', () async {
      final offset = await respondWith({
        'date': 'Fri, 06 Nov 2026 12:00:00 GMT',
      });

      expect(offset.offset, const Duration(minutes: -30));
    });

    test('a missing or malformed Date header leaves no offset', () async {
      expect((await respondWith({})).offset, Duration.zero);
      expect((await respondWith({'date': 'not a date'})).offset, Duration.zero);
    });
  });
}

class _HeadersAdapter implements HttpClientAdapter {
  final Map<String, String> headers;

  _HeadersAdapter(this.headers);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    'ok',
    200,
    headers: {
      for (final entry in headers.entries) entry.key: [entry.value],
    },
  );

  @override
  void close({bool force = false}) {}
}
