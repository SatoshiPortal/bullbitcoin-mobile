import 'package:bull_exchange/src/session/domain/usecases/get_announcements_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../buy/buy_fixtures.dart';

void main() {
  test('reads the announcements of the session environment', () async {
    final asked = <ExchangeEnvironment>[];
    final result = await GetAnnouncementsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(buySession)),
        listAnnouncements: (environment) async {
          asked.add(environment);
          return const Ok([]);
        },
      ),
    ).execute(buySession);
    expect(result, isA<Ok<List<Announcement>, ExchangeFailure>>());
    expect(asked, [buySession.environment]);
  });

  test('a session that is no longer current is refused unread', () async {
    final result = await GetAnnouncementsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(
          const ExchangeAccessSignedIn(buyOtherSession),
        ),
      ),
    ).execute(buySession);
    expect((result as Err).failure, isA<ExchangeOperationStaleFailure>());
  });

  test('a failed read is never a list', () async {
    final result = await GetAnnouncementsUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(buySession)),
        listAnnouncements: (_) async => const Err(ExchangeNetworkFailure()),
      ),
    ).execute(buySession);
    expect(
      (result as Err).failure,
      isA<ExchangeAnnouncementsUnavailableFailure>(),
    );
  });
}
