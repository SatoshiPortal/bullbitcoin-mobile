import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/util.dart';
import 'package:test/test.dart';

BoltzApiException _response(String status, String body) => BoltzApiException(
  kind: 'HTTPStatusNotSuccess',
  message: 'HTTP Status Not Success: $status, $body',
);

void main() {
  const reason = 'invoice expiry too short';
  const body = '{"error":"$reason"}';

  test('classifies the invoice expiry rejection without carrying its body', () {
    final failure = classifySwapCreationFailure(
      _response('400 Bad Request', body),
    );

    expect(failure, isA<SwapsInvoiceExpiryTooShortFailure>());
    expect(failure.logMessage, isNull);
  });

  test('only recognizes the exact error field in a bad request', () {
    for (final otherBody in ['{"error":"x","detail":"$reason"}', reason]) {
      expect(
        classifySwapCreationFailure(_response('400 Bad Request', otherBody))
            .runtimeType,
        SwapsBoltzRejectedFailure,
      );
    }
    expect(
      classifySwapCreationFailure(_response('500 Internal Server Error', body)),
      isA<SwapsBoltzUnavailableFailure>(),
    );
  });
}
