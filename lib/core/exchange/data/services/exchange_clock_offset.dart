import 'dart:io' show HttpDate, HttpException, HttpHeaders;

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';

/// How far the device clock is from the exchange's, measured from the `Date`
/// header of exchange API responses.
///
/// Order deadlines are server instants, but the blocs, the deadline scheduler
/// and the countdowns compare them with the device clock. On a device whose
/// clock runs ahead by more than the price lock, every fresh quote looks
/// expired and Confirm is refused in a loop. `OrderModel.toEntity` subtracts
/// [offset] from the deadline so those comparisons hold.
///
/// `Date` has one-second resolution, so anything within [tolerance] counts as
/// no offset, leaving correctly set devices unchanged.
class ExchangeClockOffset {
  static const tolerance = Duration(seconds: 10);
  static const _sentAtKey = 'exchangeClockOffsetSentAt';

  Duration _offset = Duration.zero;

  /// Measures the offset from every response, errors included: an error
  /// response carries the server's `Date` just the same. The device time is
  /// the midpoint between sending the request and receiving the response, so
  /// symmetric latency (a slow Tor circuit) is not counted as clock offset.
  late final Interceptor interceptor = InterceptorsWrapper(
    onRequest: (options, handler) {
      options.extra[_sentAtKey] = clock.now();
      handler.next(options);
    },
    onResponse: (response, handler) {
      _observeDateHeader(response.headers, response.requestOptions);
      handler.next(response);
    },
    onError: (error, handler) {
      final response = error.response;
      if (response != null) {
        _observeDateHeader(response.headers, error.requestOptions);
      }
      handler.next(error);
    },
  );

  /// Server time minus device time; zero while within [tolerance].
  Duration get offset => _offset;

  /// Whether the device clock is off by more than [tolerance].
  bool get isDeviceClockOff => _offset != Duration.zero;

  void observe({required DateTime serverTime, required DateTime deviceTime}) {
    final measured = serverTime.difference(deviceTime);
    final next = measured.abs() <= tolerance ? Duration.zero : measured;
    if ((next == Duration.zero) != (_offset == Duration.zero)) {
      log.fine(
        next == Duration.zero
            ? 'Device clock matches the exchange again'
            : 'Device clock is off from the exchange: '
                  'deviceAheadSeconds=${-next.inSeconds}',
      );
    }
    _offset = next;
  }

  void _observeDateHeader(Headers headers, RequestOptions request) {
    // `Headers.value` throws on a repeated header, and a throw here would
    // fail the request this measurement rides on.
    final date = headers[HttpHeaders.dateHeader]?.firstOrNull;
    if (date == null) return;
    final DateTime serverTime;
    try {
      serverTime = HttpDate.parse(date);
    } on FormatException {
      return;
    } on HttpException {
      return;
    }
    final receivedAt = clock.now();
    final sentAt = request.extra[_sentAtKey];
    if (sentAt is! DateTime || sentAt.isAfter(receivedAt)) {
      observe(serverTime: serverTime, deviceTime: receivedAt);
      return;
    }
    final roundTrip = receivedAt.difference(sentAt);
    // A round trip longer than the tolerance cannot place the server's stamp
    // within it; keep the previous measurement.
    if (roundTrip > tolerance) return;
    observe(serverTime: serverTime, deviceTime: sentAt.add(roundTrip ~/ 2));
  }
}
