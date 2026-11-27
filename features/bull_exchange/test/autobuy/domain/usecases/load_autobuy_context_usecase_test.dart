import 'package:bull_exchange/src/account/domain/usecases/get_user_summary_usecase.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_state.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/load_autobuy_context_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../autobuy_fixtures.dart';

Future<Result<AutoBuyContext, ExchangeReadFailure>> _load(
  Result<UserSummary, ExchangeFailure> summary, {
  List<ExchangeEnvironment?>? asked,
}) {
  final exchange = exchangeForTesting(
    getUserSummary: (environment) async {
      asked?.add(environment);
      return summary;
    },
    unknownWrites: InMemoryUnknownWriteJournal(),
    readSessionPoint: () async =>
        const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
  );
  return LoadAutoBuyContextUsecase(
    exchange,
    GetUserSummaryUsecase(exchange),
  ).execute(autoBuySession);
}

void main() {
  test('opens with the session summary and the journal', () async {
    final asked = <ExchangeEnvironment?>[];
    final read = await _load(Ok(autoBuySummary(active: true)), asked: asked);
    final context = (read as Ok<AutoBuyContext, ExchangeReadFailure>).value;
    expect(context.summary.autoBuy.isActive, isTrue);
    expect(context.openEntries, isEmpty);
    expect(asked, [ExchangeEnvironment.mainnet]);
  });

  test('a failed summary read is never a context', () async {
    expect(
      await _load(
        const Err(
          ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
        ),
      ),
      isA<Err<AutoBuyContext, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
    expect(
      await _load(const Err(ExchangeNetworkFailure())),
      isA<Err<AutoBuyContext, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeUnreachableFailure>(),
      ),
    );
  });
}
