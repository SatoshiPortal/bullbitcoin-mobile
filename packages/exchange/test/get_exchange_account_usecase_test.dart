import 'package:exchange/setup.dart';

import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

const _testSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

class _Access extends Mock implements ExchangeAccessLifecycle {}

abstract interface class _AccountReader {
  Future<Result<UserSummary, ExchangeFailure>> getAccount();
}

class _Account extends Mock implements _AccountReader {}

class _Expire extends Mock implements ExpireExchangeSessionUsecase {}

void main() {
  late _Access access;
  late _Account mainnet;
  late _Account testnet;
  late _Expire expire;
  late GetExchangeAccountUsecase usecase;
  var epoch = 1;
  setUp(() {
    epoch = 1;
    access = _Access();
    mainnet = _Account();
    testnet = _Account();
    expire = _Expire();
    when(() => access.current)
        .thenReturn(const ExchangeAccessSignedIn(_testSession));
    when(() => access.session).thenAnswer(
      (_) => access.current.isSignedIn
          ? ExchangeSession(
              environment: ExchangeEnvironment.mainnet,
              epoch: epoch,
              sessionId: 'test',
            )
          : null,
    );
    when(
      () => expire.execute(
        epoch: any(named: 'epoch'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    usecase = GetExchangeAccountUsecase(
      exchange: exchangeForTesting(
        getAccount: (environment) =>
            (environment == ExchangeEnvironment.mainnet ? mainnet : testnet)
                .getAccount(),
      ),
      access: access,
      expire: expire,
    );
  });

  test('current server rejection expires the matching epoch', () async {
    when(mainnet.getAccount)
        .thenAnswer((_) async => const Err(ExchangeSessionRejectedFailure()));
    expect(
      await usecase.execute(_testSession),
      isA<Err<UserSummary, ExchangeFailure>>(),
    );
    verify(() => expire.execute(epoch: 1, isTestnet: false)).called(1);
  });

  test('old server rejection cannot expire a newer session', () async {
    final pending = Completer<Result<UserSummary, ExchangeFailure>>();
    when(mainnet.getAccount).thenAnswer((_) => pending.future);
    final result = usecase.execute(_testSession);
    await Future<void>.delayed(Duration.zero);
    epoch++;
    pending.complete(const Err(ExchangeSessionRejectedFailure()));
    expect((await result as Err).failure, isA<ExchangeOperationStaleFailure>());
    verifyNever(
      () => expire.execute(
        epoch: any(named: 'epoch'),
        isTestnet: any(named: 'isTestnet'),
      ),
    );
  });

  for (final failure in <ExchangeFailure>[
    const ExchangeNotAuthenticatedFailure(),
    const ExchangeAccountUnavailableFailure(),
    const ExchangeNetworkFailure(),
  ]) {
    test('$failure does not expire a credential', () async {
      when(mainnet.getAccount).thenAnswer((_) async => Err(failure));
      expect(
        (await usecase.execute(_testSession) as Err).failure,
        same(failure),
      );
      verifyNever(
        () => expire.execute(
          epoch: any(named: 'epoch'),
          isTestnet: any(named: 'isTestnet'),
        ),
      );
    });
  }

  test('signed out access does not read the account or expire', () async {
    when(() => access.current)
        .thenReturn(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    expect(
      (await usecase.execute(_testSession) as Err).failure,
      isA<ExchangeNotAuthenticatedFailure>(),
    );
    verifyZeroInteractions(mainnet);
    verifyNever(
      () => expire.execute(
        epoch: any(named: 'epoch'),
        isTestnet: any(named: 'isTestnet'),
      ),
    );
  });

  test('a session that is not current is refused without a read', () async {
    epoch = 2;
    expect(
      (await usecase.execute(_testSession) as Err).failure,
      isA<ExchangeOperationStaleFailure>(),
    );
    verifyZeroInteractions(mainnet);
  });

  test('a testnet session uses the testnet account repository', () async {
    const session = ExchangeSession(
      environment: ExchangeEnvironment.testnet,
      epoch: 1,
      sessionId: 'test',
    );
    when(() => access.session).thenReturn(session);
    when(testnet.getAccount)
        .thenAnswer((_) async => const Err(ExchangeSessionRejectedFailure()));
    await usecase.execute(session);
    verify(testnet.getAccount).called(1);
    verifyZeroInteractions(mainnet);
    verify(() => expire.execute(epoch: 1, isTestnet: true)).called(1);
  });
}
