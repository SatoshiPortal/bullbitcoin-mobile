import 'package:bull_exchange/src/dca/domain/dca_state.dart';
import 'package:bull_exchange/src/dca/domain/usecases/load_dca_context_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../dca_fixtures.dart';

Future<Result<DcaContext, ExchangeReadFailure>> _load({
  Result<UserSummary, ExchangeFailure>? summary,
  Result<DefaultWallets, ExchangeFailure> wallets = const Ok(dcaWallets),
  List<ExchangeEnvironment?>? asked,
  ExchangeSession signedIn = buySession,
}) => LoadDcaContextUsecase(
  exchangeForTesting(
    access: fixedAccessForTesting(ExchangeAccessSignedIn(signedIn)),
    getUserSummary: (environment) async {
      asked?.add(environment);
      return summary ?? Ok(buySummaryWith());
    },
    getDefaultWallets: () async => wallets,
    unknownWrites: InMemoryUnknownWriteJournal(),
    readSessionPoint: () async =>
        const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
  ),
).execute(buySession);

void main() {
  test('opens with the session summary, the default wallets and the '
      'journal', () async {
    final asked = <ExchangeEnvironment?>[];
    final read = await _load(asked: asked);
    final context = (read as Ok<DcaContext, ExchangeReadFailure>).value;
    expect(context.defaultWallets, dcaWallets);
    expect(context.openEntries, isEmpty);
    expect(asked, [ExchangeEnvironment.mainnet]);
  });

  test('a session rejection in either read wins over an unreachable '
      'one', () async {
    expect(
      await _load(
        summary: const Err(ExchangeNetworkFailure()),
        wallets: const Err(
          ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
        ),
      ),
      isA<Err<DcaContext, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
    expect(
      await _load(wallets: const Err(ExchangeNetworkFailure())),
      isA<Err<DcaContext, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeUnreachableFailure>(),
      ),
    );
  });

  test(
    'a session that is no longer current reads no default wallets',
    () async {
      expect(
        await _load(
          wallets: const Err(ExchangeNetworkFailure()),
          signedIn: const ExchangeSession(
            environment: ExchangeEnvironment.mainnet,
            epoch: 99,
            sessionId: 'later',
          ),
        ),
        isA<Err<DcaContext, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeSessionRejectedFailure>().having(
            (r) => r.why,
            'why',
            ExchangeSessionRejection.sessionChanged,
          ),
        ),
      );
    },
  );
}
