import 'package:bull_exchange/src/dca/domain/usecases/activate_dca_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../dca_fixtures.dart';

void main() {
  test('turns the DCA preference on for the signed-in session', () async {
    final written = <String>[];
    await ActivateDcaUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(buySession)),
        getUserSummary: (_) async => Ok(buySummaryWith()),
        saveUserPreference:
            (
              environment, {
              language,
              currency,
              dcaEnabled,
              autoBuyEnabled,
              emailNotificationsEnabled,
            }) async {
              written.add('${environment.name} dca=$dcaEnabled');
              return const Ok(null);
            },
      ),
    ).execute(buySession);
    expect(written, ['mainnet dca=true']);
  });

  test('a session that is no longer current writes nothing', () async {
    const later = ExchangeSession(
      environment: ExchangeEnvironment.mainnet,
      epoch: 99,
      sessionId: 'later',
    );
    await expectLater(
      ActivateDcaUsecase(
        exchangeForTesting(
          access: fixedAccessForTesting(const ExchangeAccessSignedIn(later)),
        ),
      ).execute(buySession),
      completes,
    );
  });

  test('a failed write is only logged: the recurring buy exists', () async {
    await expectLater(
      ActivateDcaUsecase(exchangeForTesting()).execute(buySession),
      completes,
    );
  });
}
