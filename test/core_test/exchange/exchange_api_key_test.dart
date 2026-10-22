import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

Result<ExchangeApiKey, ExchangeApiKeyFailure> _create(String key) =>
    ExchangeApiKey.create(
      id: 'id',
      key: key,
      name: 'name',
      userId: 'user',
      isActive: true,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  test(
    'a valid credential retains its fields without exposing the key in diagnostics',
    () {
      const key = 'synthetic-key_+/=';
      switch (_create(key)) {
        case Ok(:final value):
          expect(value.id, 'id');
          expect(value.key, key);
          expect(value.isActive, isTrue);
          expect(value.toString(), isNot(contains(key)));
        case Err():
          fail('Expected a valid credential');
      }
    },
  );

  for (final key in [
    '',
    ' ',
    'synthetic\r\nheader',
    'synthetic\u0000',
    'synthetic\u{1f600}',
  ]) {
    test(
      'invalid header material is a failure without retaining its value',
      () {
        final result = _create(key);
        expect(result, isA<Err<ExchangeApiKey, ExchangeApiKeyFailure>>());
        if (result case Err(:final failure)) {
          expect(failure.logMessage, isNull);
        }
      },
    );
  }
}
