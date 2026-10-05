import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('raises a short onion timeout to thirty seconds', () {
    expect(
      _connection('ssl://hidden.onion:50002', timeout: 5).effectiveTimeout,
      30,
    );
  });

  test('preserves an onion timeout above the minimum', () {
    expect(
      _connection('ssl://hidden.onion:50002', timeout: 45).effectiveTimeout,
      45,
    );
  });

  test('preserves the configured clearnet timeout', () {
    expect(
      _connection(
        'ssl://electrum.example.com:50002',
        timeout: 5,
      ).effectiveTimeout,
      5,
    );
  });

  test('recognizes an onion host with a trailing dot', () {
    expect(
      _connection('ssl://hidden.onion.:50002', timeout: 5).effectiveTimeout,
      30,
    );
  });
}

ElectrumConnection _connection(String url, {required int timeout}) =>
    ElectrumConnection(
      url: url,
      retry: 1,
      timeout: timeout,
      stopGap: 20,
      validateDomain: true,
      isCustom: true,
    );
