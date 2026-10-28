import 'package:bb_mobile/core/exchange/data/mappers/bbx_api_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_failure.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in {
    bbx.ApiErrorKind.network: ExchangeApiNetworkFailure,
    bbx.ApiErrorKind.timeout: ExchangeApiTimeoutFailure,
    bbx.ApiErrorKind.outcomeUnknown: ExchangeApiOutcomeUnknownFailure,
    bbx.ApiErrorKind.unauthenticated: ExchangeApiUnauthenticatedFailure,
    bbx.ApiErrorKind.validation: ExchangeApiValidationFailure,
    bbx.ApiErrorKind.maintenance: ExchangeApiMaintenanceFailure,
    bbx.ApiErrorKind.forbidden: ExchangeApiUnexpectedFailure,
    bbx.ApiErrorKind.parse: ExchangeApiUnexpectedFailure,
  }.entries) {
    test('${entry.key.name} maps to an app failure without server text', () {
      final failure = BbxApiMapper.apiFailure(
        bbx.ApiError(kind: entry.key, serverMessage: 'private server detail'),
      );
      expect(failure.runtimeType, entry.value);
      expect(failure.logMessage, isNot(contains('private server detail')));
    });
  }
}
