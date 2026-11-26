import 'package:bb_mobile/core/exchange/data/services/exchange_clock_offset.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final serverNow = DateTime.utc(2026, 11, 6, 12);

  group('observe', () {
    test('an offset within tolerance counts as none', () {
      final offset = ExchangeClockOffset()
        ..observe(
          serverTime: serverNow,
          deviceTime: serverNow.add(const Duration(seconds: 10)),
        );

      expect(offset.offset, Duration.zero);
      expect(offset.isDeviceClockOff, isFalse);
    });

    test('a device clock running ahead gives a negative offset', () {
      final offset = ExchangeClockOffset()
        ..observe(
          serverTime: serverNow,
          deviceTime: serverNow.add(const Duration(minutes: 30)),
        );

      expect(offset.offset, const Duration(minutes: -30));
      expect(offset.isDeviceClockOff, isTrue);
    });

    test('a device clock running behind gives a positive offset', () {
      final offset = ExchangeClockOffset()
        ..observe(
          serverTime: serverNow,
          deviceTime: serverNow.subtract(const Duration(minutes: 30)),
        );

      expect(offset.offset, const Duration(minutes: 30));
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
    /// Sends one request through the interceptor. The device clock reads
    /// [sentAt] when the request leaves and moves by [latency] while the
    /// server answers with [headers] and [status].
    Future<ExchangeClockOffset> respondWith(
      Map<String, List<String>> headers, {
      int status = 200,
      DateTime? sentAt,
      Duration latency = Duration.zero,
    }) async {
      final offset = ExchangeClockOffset();
      var now = sentAt ?? serverNow.add(const Duration(minutes: 30));
      final dio = Dio()
        ..interceptors.add(offset.interceptor)
        ..httpClientAdapter = _HeadersAdapter(
          headers,
          status: status,
          onFetch: () => now = now.add(latency),
        );
      await withClock(Clock(() => now), () async {
        try {
          await dio.get<String>('https://api.example/');
        } on DioException catch (e) {
          if (e.response == null) rethrow;
        }
      });
      return offset;
    }

    test('reads the Date header of a response', () async {
      final offset = await respondWith({
        'date': ['Fri, 06 Nov 2026 12:00:00 GMT'],
      });

      expect(offset.offset, const Duration(minutes: -30));
    });

    test('reads the Date header of an error response', () async {
      final offset = await respondWith({
        'date': ['Fri, 06 Nov 2026 12:00:00 GMT'],
      }, status: 500);

      expect(offset.offset, const Duration(minutes: -30));
    });

    test(
      'a repeated Date header neither fails the request nor is ignored',
      () async {
        final offset = await respondWith({
          'date': [
            'Fri, 06 Nov 2026 12:00:00 GMT',
            'Fri, 06 Nov 2026 12:00:01 GMT',
          ],
        });

        expect(offset.offset, const Duration(minutes: -30));
      },
    );

    test('latency is not counted as clock offset', () async {
      // A correct clock and a 40 s round trip: the server stamped its Date
      // halfway, 20 s after the request left.
      final offset = await respondWith(
        {
          'date': ['Fri, 06 Nov 2026 12:00:20 GMT'],
        },
        sentAt: serverNow,
        latency: const Duration(seconds: 40),
      );

      expect(offset.offset, Duration.zero);
    });

    test('a round trip longer than the tolerance is discarded', () async {
      // Device 30 minutes ahead, but the answer took 40 s: the sample cannot
      // place the server's stamp within the tolerance, so it is not used.
      final offset = await respondWith({
        'date': ['Fri, 06 Nov 2026 12:00:20 GMT'],
      }, latency: const Duration(seconds: 40));

      expect(offset.offset, Duration.zero);
    });

    test('a missing or malformed Date header leaves no offset', () async {
      expect((await respondWith({})).offset, Duration.zero);
      expect(
        (await respondWith({
          'date': ['not a date'],
        })).offset,
        Duration.zero,
      );
    });
  });
}

class _HeadersAdapter implements HttpClientAdapter {
  final Map<String, List<String>> headers;
  final int status;
  final void Function() onFetch;

  _HeadersAdapter(this.headers, {required this.status, required this.onFetch});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch();
    return ResponseBody.fromString('ok', status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}
