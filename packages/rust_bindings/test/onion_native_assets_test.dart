import 'package:bull_sdk/onion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDownAll(OnionCore.dispose);

  test(
    'loads Onion through Native Assets and returns a native failure',
    () async {
      await OnionCore.init();
      await expectLater(
        TorService.startWithSnowflake(
          stateDir: 'unused',
          cacheDir: 'unused',
          socksPort: 0,
          snowflakePort: 0,
          policy: SocksPolicy.any,
        ),
        throwsA(
          isA<TorFailure>().having(
            (failure) => failure.kind,
            'kind',
            TorFailureKind.configuration,
          ),
        ),
      );
    },
  );
}
