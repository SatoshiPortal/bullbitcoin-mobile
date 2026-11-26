import 'package:bull_exchange/src/settings/domain/exchange_access_actions.dart';
import 'package:bull_exchange/src/settings/domain/usecases/enable_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/resolve_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/sign_out_of_exchange_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/watch_exchange_access_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// Host actions that log each call and answer with [answer].
ExchangeAccessActions _actions(
  List<String> calls, {
  Result<void, ExchangeFailure> answer = const Ok(null),
}) => (
  current: () {
    calls.add('current');
    return const ExchangeAccessUnreadable();
  },
  watch: () {
    calls.add('watch');
    return Stream.value(const ExchangeAccessDisabled());
  },
  enable: () async {
    calls.add('enable');
    return answer;
  },
  signOut: () async {
    calls.add('signOut');
    return answer;
  },
  resolve: () async {
    calls.add('resolve');
    return answer;
  },
);

void main() {
  test('the current access is the host\'s', () {
    final calls = <String>[];
    expect(
      GetExchangeAccessUsecase(_actions(calls)).execute(),
      isA<ExchangeAccessUnreadable>(),
    );
    expect(calls, ['current']);
  });

  test('access changes are the host\'s', () async {
    final calls = <String>[];
    expect(
      await WatchExchangeAccessUsecase(_actions(calls)).execute().toList(),
      [isA<ExchangeAccessDisabled>()],
    );
    expect(calls, ['watch']);
  });

  test('enabling only activates, never signs out', () async {
    final calls = <String>[];
    final failed = await EnableExchangeAccessUsecase(
      _actions(calls, answer: const Err(ExchangeUnexpectedFailure())),
    ).execute();
    expect(failed, isA<Err<void, ExchangeFailure>>());
    expect(calls, ['enable']);
  });

  test('signing out keeps its cleanup failure and never activates', () async {
    final calls = <String>[];
    final result = await SignOutOfExchangeUsecase(
      _actions(calls, answer: const Err(ExchangeSessionClearFailure())),
    ).execute();
    expect(
      result,
      isA<Err<void, ExchangeFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSessionClearFailure>(),
      ),
    );
    expect(calls, ['signOut']);
  });

  test(
    'signing out on the exchange without access keeps the failure',
    () async {
      final result = await SignOutOfExchangeUsecase.of(exchangeForTesting())
          .execute();
      expect((result as Err).failure, isA<ExchangeSessionClearFailure>());
    },
  );

  test('retry resolves the access', () async {
    final calls = <String>[];
    final result = await ResolveExchangeAccessUsecase(_actions(calls))
        .execute();
    expect(result, isA<Ok<void, ExchangeFailure>>());
    expect(calls, ['resolve']);
  });
}
