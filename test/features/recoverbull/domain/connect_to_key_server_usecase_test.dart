import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
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

  Future<bool> run() => usecase.execute(onAttempt: attempts.add);

  test('stops at the first answer instead of exhausting the budget', () async {
    when(() => checkConnection.execute()).thenAnswer((_) async => true);

    expect(await run(), isTrue);
    expect(attempts, [1]);
    verify(() => checkConnection.execute()).called(1);
  });

  test('gives up after the attempt budget', () async {
    when(() => checkConnection.execute()).thenAnswer((_) async => false);

    expect(await run(), isFalse);
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
        return calls == 2;
      });

      expect(await run(), isTrue);
      expect(attempts, [1, 2]);
    },
  );

  test('backs off between attempts', () async {
    when(() => checkConnection.execute()).thenAnswer((_) async => false);

    await run();

    expect(waited, const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
    ]);
  });
}
