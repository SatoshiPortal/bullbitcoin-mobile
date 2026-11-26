import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

void main() {
  late MockSpAccountRepository repository;
  late ScanSpWalletUsecase usecase;
  late FakeSpFeatureGateUsecase gate;

  setUp(() {
    repository = MockSpAccountRepository();
    gate = FakeSpFeatureGateUsecase();
    usecase = ScanSpWalletUsecase(
      getSpFeatureGateUsecase: gate,
      repository: repository,
    );
  });

  test(
    'closed capability gate refuses a new scan without touching the account',
    () async {
      gate.allowed = false;
      final result = await usecase.execute();
      expect((result as Err).failure, isA<SilentUnsupportedNetwork>());
      verifyZeroInteractions(repository);
    },
  );

  group('ScanSpWalletUsecase', () {
    test('calls scanOnce exactly once on the repository', () async {
      when(
        () => repository.scanOnce(
          startHeight: any(named: 'startHeight'),
          automatic: any(named: 'automatic'),
        ),
      ).thenAnswer((_) async => const Ok<void, SilentFailure>(null));

      final result = await usecase.execute();

      expect(result, isA<Ok<void, SilentFailure>>());
      verify(
        () => repository.scanOnce(
          startHeight: any(named: 'startHeight'),
          automatic: any(named: 'automatic'),
        ),
      ).called(1);
    });

    test(
      'each execute() delegates to scanOnce (idempotent pass-through)',
      () async {
        when(
          () => repository.scanOnce(
            startHeight: any(named: 'startHeight'),
            automatic: any(named: 'automatic'),
          ),
        ).thenAnswer((_) async => const Ok<void, SilentFailure>(null));

        expect(await usecase.execute(), isA<Ok<void, SilentFailure>>());
        expect(await usecase.execute(), isA<Ok<void, SilentFailure>>());

        // Two calls => two delegations, one-to-one. The use case adds no
        // dedup/throttle of its own; it is a thin pass-through.
        verify(
          () => repository.scanOnce(
            startHeight: any(named: 'startHeight'),
            automatic: any(named: 'automatic'),
          ),
        ).called(2);
      },
    );

    test('rethrows the exact error thrown by scanOnce', () async {
      final scanError = StateError('scan backend offline');
      when(
        () => repository.scanOnce(
          startHeight: any(named: 'startHeight'),
          automatic: any(named: 'automatic'),
        ),
      ).thenAnswer((_) async => throw scanError);

      // The same instance must propagate unchanged (no wrapping/swallowing).
      await expectLater(usecase.execute(), throwsA(same(scanError)));

      verify(
        () => repository.scanOnce(
          startHeight: any(named: 'startHeight'),
          automatic: any(named: 'automatic'),
        ),
      ).called(1);
    });

    test('does not touch any repository method other than scanOnce', () async {
      when(
        () => repository.scanOnce(
          startHeight: any(named: 'startHeight'),
          automatic: any(named: 'automatic'),
        ),
      ).thenAnswer((_) async => const Ok<void, SilentFailure>(null));

      expect(await usecase.execute(), isA<Ok<void, SilentFailure>>());

      verify(
        () => repository.scanOnce(
          startHeight: any(named: 'startHeight'),
          automatic: any(named: 'automatic'),
        ),
      ).called(1);
      // The scan entry point must never stop a scan or tear down the session.
      verifyNever(() => repository.stopScan());
      verifyNever(() => repository.dispose());
      verifyNoMoreInteractions(repository);
    });

    test('forwards a chosen start height to scanOnce', () async {
      when(
        () => repository.scanOnce(
          startHeight: any(named: 'startHeight'),
          automatic: any(named: 'automatic'),
        ),
      ).thenAnswer((_) async => const Ok<void, SilentFailure>(null));

      expect(
        await usecase.execute(startHeight: 800000),
        isA<Ok<void, SilentFailure>>(),
      );

      verify(() => repository.scanOnce(startHeight: 800000, automatic: null))
          .called(1);
    });

    test('forwards an automatic admission untouched', () async {
      when(
        () => repository.scanOnce(
          startHeight: any(named: 'startHeight'),
          automatic: any(named: 'automatic'),
        ),
      ).thenAnswer((_) async => const Ok<void, SilentFailure>(null));

      expect(
        await usecase.execute(automatic: (revision: 7)),
        isA<Ok<void, SilentFailure>>(),
      );

      verify(
        () => repository.scanOnce(startHeight: null, automatic: (revision: 7)),
      ).called(1);
    });
  });
}
