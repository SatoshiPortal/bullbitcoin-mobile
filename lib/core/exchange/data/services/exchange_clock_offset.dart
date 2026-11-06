import 'dart:io' show HttpDate, HttpException, HttpHeaders;

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';

/// How far the device clock is from the exchange's, measured from the `Date`
/// header of exchange API responses.
///
/// Order deadlines are server instants, but the blocs, the deadline scheduler
/// and the countdowns compare them with the device clock. On a device whose
/// clock runs ahead by more than the price lock, every fresh quote looks
/// expired and Confirm is refused in a loop. [toDeviceClock] re-expresses a
/// server deadline on the device clock so those comparisons hold.
///
/// `Date` has one-second resolution and is stamped before the response travels,
/// so a correct clock measures a small negative offset; anything within
/// [tolerance] counts as no offset, leaving correctly set devices unchanged.
class ExchangeClockOffset {
  static const tolerance = Duration(seconds: 10);

  Duration _offset = Duration.zero;

  /// Server time minus device time; zero while within [tolerance].
  Duration get offset => _offset;

  void observe({required DateTime serverTime, required DateTime deviceTime}) {
    final measured = serverTime.difference(deviceTime);
    _offset = measured.abs() <= tolerance ? Duration.zero : measured;
  }

  /// [serverInstant] as the device clock will read it.
  DateTime toDeviceClock(DateTime serverInstant) =>
      serverInstant.subtract(_offset);

  /// Measures the offset from every response, errors included: an error
  /// response carries the server's `Date` just the same.
  Interceptor get interceptor => InterceptorsWrapper(
    onResponse: (response, handler) {
      _observeDateHeader(response.headers);
      handler.next(response);
    },
    onError: (error, handler) {
      final headers = error.response?.headers;
      if (headers != null) _observeDateHeader(headers);
      handler.next(error);
    },
  );

  void _observeDateHeader(Headers headers) {
    final date = headers.value(HttpHeaders.dateHeader);
    if (date == null) return;
    final DateTime serverTime;
    try {
      serverTime = HttpDate.parse(date);
    } on FormatException {
      return;
    } on HttpException {
      return;
    }
    observe(serverTime: serverTime, deviceTime: clock.now());
  }
}
