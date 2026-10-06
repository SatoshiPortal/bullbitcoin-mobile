import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/funding_datasource_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The gateway logs these with `log.warning(..., error: e)`, and the log
  // stores `error.toString()`. These pin what actually reaches the log.
  group('FundingDatasourceException.toString', () {
    test('an RPC refusal logs its code but not the backend sentence', () {
      const iban = 'DE89370400440532013000';
      const e = FundingRpcException(
        apiCode: 'ERR_ORD_CSRCP400',
        logMessage: 'Please activate virtual payment for IBAN $iban',
      );

      expect(e.toString(), contains('ERR_ORD_CSRCP400'));
      expect(e.toString(), isNot(contains(iban)));
      expect(e.toString(), isNot(contains('Instance of')));
    });

    test('a transport failure logs the gateway-written reason', () {
      const e = FundingNetworkException('HTTP 503');

      expect(e.toString(), 'FundingNetworkException(HTTP 503)');
    });

    test('a malformed response logs the gateway-written reason', () {
      const e = FundingResponseException('Missing RPC result');

      expect(e.toString(), 'FundingResponseException(Missing RPC result)');
    });
  });
}
