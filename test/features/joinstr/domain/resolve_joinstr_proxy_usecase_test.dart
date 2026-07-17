import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_proxy_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTor extends Mock implements TorDatasource {}

void main() {
  late _MockTor tor;

  ResolveJoinstrProxyUsecase build() => ResolveJoinstrProxyUsecase(
    torDatasource: tor,
    timeout: const Duration(milliseconds: 300),
    pollInterval: const Duration(milliseconds: 10),
  );

  setUp(() => tor = _MockTor());

  test(
    'waits for a bootstrapping Tor rather than failing immediately',
    () async {
      // start() returns while Tor is still bootstrapping; isStarted only flips
      // true after a few polls. This is the case that used to throw
      // torUnavailable the instant Create was tapped.
      var polls = 0;
      when(() => tor.isStarted).thenAnswer((_) => polls++ >= 3);
      when(() => tor.start()).thenAnswer((_) async {});
      when(() => tor.port).thenReturn(9050);

      expect(await build().execute(), '127.0.0.1:9050');
    },
  );

  test('does not restart Tor when it is already online', () async {
    when(() => tor.isStarted).thenReturn(true);
    when(() => tor.port).thenReturn(9051);

    expect(await build().execute(), '127.0.0.1:9051');
    verifyNever(() => tor.start());
  });

  test('throws torUnavailable when Tor never comes online', () async {
    when(() => tor.isStarted).thenReturn(false);
    when(() => tor.start()).thenAnswer((_) async {});
    when(() => tor.port).thenReturn(-1);

    await expectLater(
      () => build().execute(),
      throwsA(
        isA<JoinstrException>().having(
          (e) => e.issue,
          'issue',
          JoinstrIssue.torUnavailable,
        ),
      ),
    );
  });

  test('recovers from a start() that throws by polling readiness', () async {
    // A concurrent start may be mid-bootstrap and this start() throws; the
    // usecase must fall through to the poll instead of surfacing the error.
    var polls = 0;
    when(() => tor.isStarted).thenAnswer((_) => polls++ >= 2);
    when(() => tor.start()).thenThrow(Exception('already starting'));
    when(() => tor.port).thenReturn(9050);

    expect(await build().execute(), '127.0.0.1:9050');
  });
}
