import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/connect_to_key_server_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckServerConnection extends Mock
    implements CheckServerConnectionUsecase {}

void main() {
  late _MockCheckServerConnection checkConnection;
  late List<Duration> waited;
  late List<int> attempts;
  late ConnectToKeyServerUsecase usecase;

  setUp(() {
    checkConnection = _MockCheckServerConnection();
    waited = [];
    attempts = [];
    usecase = ConnectToKeyServerUsecase(
      checkConnection,
      wait: (duration) async => waited.add(duration),
    );
  });

  Future<Result<bool, RecoverBullCoreFailure>> run() =>
      usecase.execute(onAttempt: attempts.add);

  test('stops at the first answer instead of exhausting the budget', () async {
    when(
      () => checkConnection.execute(),
    ).thenAnswer((_) async => const Ok(true));

    expect(await run(), isA<Ok<bool, RecoverBullCoreFailure>>());
    expect(attempts, [1]);
    verify(() => checkConnection.execute()).called(1);
  });

  test('gives up after the attempt budget', () async {
    when(
      () => checkConnection.execute(),
    ).thenAnswer((_) async => const Ok(false));

    expect(await run(), isA<Ok<bool, RecoverBullCoreFailure>>());
    expect(attempts, [1, 2, 3]);
    expect(attempts.length, ConnectToKeyServerUsecase.maxAttempts);
    verify(
      () => checkConnection.execute(),
    ).called(ConnectToKeyServerUsecase.maxAttempts);
  });

  test(
    'reports the attempt that is in flight, not the one that failed',
    () async {
      var calls = 0;
      when(() => checkConnection.execute()).thenAnswer((_) async {
        // The attempt must already be published when the call runs, otherwise
        // the screen names the previous one.
        expect(attempts.last, calls + 1);
        calls++;
        return Ok(calls == 2);
      });

      expect(await run(), isA<Ok<bool, RecoverBullCoreFailure>>());
      expect(attempts, [1, 2]);
    },
  );

  test('tries immediately, then backs off between retries', () async {
    when(
      () => checkConnection.execute(),
    ).thenAnswer((_) async => const Ok(false));

    await run();

    expect(waited, const [Duration(seconds: 1), Duration(seconds: 2)]);
  });

  test('does not delay a server that answers at once', () async {
    when(
      () => checkConnection.execute(),
    ).thenAnswer((_) async => const Ok(true));

    await run();

    expect(waited, isEmpty);
  });

  test('does not retry an unavailable external proxy', () async {
    when(
      () => checkConnection.execute(),
    ).thenAnswer((_) async => const Err(ExternalTorProxyUnavailableFailure()));

    final result = await usecase.execute(onAttempt: attempts.add);

    expect(result, isA<Err<bool, RecoverBullCoreFailure>>());
    expect(attempts, [1]);
    expect(waited, isEmpty);
  });
}
