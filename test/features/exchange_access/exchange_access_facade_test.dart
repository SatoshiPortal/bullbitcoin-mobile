import 'dart:async';

import 'package:bb_mobile/features/exchange_access/data/exchange_access_repository_impl.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BlockingRepository implements ExchangeAccessRepository {
  final started = Completer<void>();
  final completion = Completer<Result<void, ExchangeAccessFailure>>();

  @override
  Future<Result<Map<bool, ExchangeAccess>, ExchangeAccessFailure>>
  read() async =>
      const Ok({false: ExchangeAccess(choice: ExchangeAccessChoice.disabled)});

  @override
  Future<Result<void, ExchangeAccessFailure>> write(
    Map<bool, ExchangeAccess> values,
  ) {
    started.complete();
    return completion.future;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'legacy anonymous is disabled while explicit wizard ON survives restart',
    () async {
      final first = ExchangeAccessFacade();
      expect(
        await first.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.anonymous,
        ),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(first.current.choice, ExchangeAccessChoice.disabled);
      expect(
        await first.choose(true),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      final restarted = ExchangeAccessFacade();
      expect(
        await restarted.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.anonymous,
        ),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(restarted.current.enabledForHome, isTrue);
      await first.dispose();
      await restarted.dispose();
    },
  );

  test('legacy authenticated is enabled only in its environment', () async {
    final access = ExchangeAccessFacade();
    expect(
      await access.initialize(
        isTestnet: false,
        session: ExchangeSessionFact.authenticated,
      ),
      isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
    );
    expect(access.current.canUseAuthenticatedExchange, isTrue);
    expect(
      await access.initialize(
        isTestnet: true,
        session: ExchangeSessionFact.anonymous,
      ),
      isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
    );
    expect(access.current.choice, ExchangeAccessChoice.disabled);
    await access.dispose();
  });

  test(
    'failed cleanup stays pending through restart and can be retried',
    () async {
      final access = ExchangeAccessFacade();
      expect(
        await access.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.authenticated,
        ),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(
        await access.disable(() async => false),
        isA<Err<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(access.current.transition, ExchangeAccessTransition.disabling);
      expect(access.current.enabledForHome, isFalse);
      final restarted = ExchangeAccessFacade();
      expect(
        await restarted.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.authenticated,
        ),
        isA<Err<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(restarted.current.transition, ExchangeAccessTransition.disabling);
      expect(
        await restarted.disable(() async => true),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(restarted.current.choice, ExchangeAccessChoice.disabled);
      expect(restarted.current.session, ExchangeSessionFact.anonymous);
      await access.dispose();
      await restarted.dispose();
    },
  );

  test(
    'network failure retains recognized session and marks data stale',
    () async {
      final access = ExchangeAccessFacade();
      expect(
        await access.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.authenticated,
        ),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(
        await access.reconcileSession(ExchangeSessionFact.networkUnavailable),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(access.current.session, ExchangeSessionFact.authenticated);
      expect(access.current.isStale, isTrue);
      expect(access.current.enabledForHome, isTrue);
      await access.dispose();
    },
  );

  test('invalid stored format is not treated as absent', () async {
    SharedPreferences.setMockInitialValues({
      ExchangeAccessRepositoryImpl.key: '{bad',
    });
    final access = ExchangeAccessFacade();
    final result = await access.initialize(
      isTestnet: false,
      session: ExchangeSessionFact.anonymous,
    );
    expect(result, isA<Err<ExchangeAccessOutcome, ExchangeAccessFailure>>());
    expect(access.current.choice, ExchangeAccessChoice.unset);
    await access.dispose();
  });

  test('late authentication cannot reactivate access after disable', () async {
    final access = ExchangeAccessFacade();
    expect(
      await access.initialize(
        isTestnet: false,
        session: ExchangeSessionFact.authenticated,
      ),
      isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
    );
    final oldGeneration = access.generation;
    final cleanup = Completer<bool>();
    final disabling = access.disable(() => cleanup.future);
    final late = access.reconcileSession(
      ExchangeSessionFact.authenticated,
      generation: oldGeneration,
    );
    cleanup.complete(true);
    expect(
      await disabling,
      isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
    );
    expect(
      (await late as Ok<ExchangeAccessOutcome, ExchangeAccessFailure>).value,
      ExchangeAccessOutcome.stale,
    );
    expect(access.current.choice, ExchangeAccessChoice.disabled);
    await access.dispose();
  });

  test(
    'stored recognized layout survives a resolving session without granting auth',
    () async {
      final first = ExchangeAccessFacade();
      expect(
        await first.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.authenticated,
        ),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      final restarted = ExchangeAccessFacade();
      expect(
        await restarted.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.resolving,
        ),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(restarted.current.lastKnownAuthenticated, isTrue);
      expect(restarted.current.enabledForHome, isTrue);
      expect(restarted.current.canUseAuthenticatedExchange, isFalse);
      await first.dispose();
      await restarted.dispose();
    },
  );

  test(
    'suspending resolution retains layout and closes authenticated access',
    () async {
      final access = ExchangeAccessFacade();
      expect(
        await access.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.authenticated,
        ),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      final generation = access.generation;
      access.suspend();
      expect(access.current.enabledForHome, isTrue);
      expect(access.current.canUseAuthenticatedExchange, isFalse);
      expect(access.generation, greaterThan(generation));
      await access.dispose();
    },
  );

  for (final shouldFail in [false, true]) {
    test(
      'stale reconciliation cannot publish after a ${shouldFail ? 'failed' : 'successful'} write',
      () async {
        final repository = _BlockingRepository();
        final access = ExchangeAccessFacade(repository: repository);
        expect(
          await access.initialize(
            isTestnet: false,
            session: ExchangeSessionFact.anonymous,
          ),
          isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
        );
        final pending = access.reconcileSession(
          ExchangeSessionFact.authenticated,
        );
        await repository.started.future;
        access.suspend();
        repository.completion.complete(
          shouldFail
              ? const Err(ExchangeAccessStorageFailure())
              : const Ok(null),
        );
        final result = await pending;
        expect(
          (result as Ok<ExchangeAccessOutcome, ExchangeAccessFailure>).value,
          ExchangeAccessOutcome.stale,
        );
        expect(access.current.session, ExchangeSessionFact.resolving);
        expect(access.current.choice, ExchangeAccessChoice.disabled);
        expect(access.current.canUseAuthenticatedExchange, isFalse);
        await access.dispose();
      },
    );
  }
}
