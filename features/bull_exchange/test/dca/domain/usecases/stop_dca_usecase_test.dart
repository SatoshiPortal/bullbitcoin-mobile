import 'package:bull_exchange/src/dca/domain/usecases/stop_dca_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../dca_fixtures.dart';

UserSummary _activeDca() {
  final summary = buySummaryWith();
  return UserSummary(
    userNumber: summary.userNumber,
    groups: summary.groups,
    profile: summary.profile,
    email: summary.email,
    balances: summary.balances,
    dca: const UserDca(isActive: true),
    autoBuy: summary.autoBuy,
  );
}

void main() {
  test('turns the recurring buy off for the session environment', () async {
    final written = <String>[];
    final result = await StopDcaUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(buySession)),
        getUserSummary: (_) async => Ok(_activeDca()),
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
    expect(result, isA<Ok<void, ExchangeFailure>>());
    expect(written, ['mainnet dca=false']);
  });

  test('a session that is no longer current writes nothing', () async {
    final result = await StopDcaUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(
          const ExchangeAccessSignedIn(buyOtherSession),
        ),
      ),
    ).execute(buySession);
    expect((result as Err).failure, isA<ExchangeOperationStaleFailure>());
  });
}
