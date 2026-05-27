import 'package:bb_mobile/core/electrum/domain/electrum_fallback_runner.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal server type to prove the runner is genuinely generic — the
/// broadcast/sync paths feed it a different value object than the electrum
/// entity, so the [urlOf]/[isCustomOf] extractors must carry the metadata.
class _Server {
  final String url;
  final bool isCustom;
  const _Server(this.url, {this.isCustom = false});
}

Future<R> _run<R>(
  List<_Server> servers,
  Future<R> Function(_Server) op, {
  bool Function(Object)? isTransient,
}) {
  return runElectrumFallback<_Server, R>(
    servers: servers,
    urlOf: (s) => s.url,
    isCustomOf: (s) => s.isCustom,
    operation: op,
    isTransient: isTransient,
  );
}

void main() {
  group('runElectrumFallback', () {
    test('returns the first success without touching later servers', () async {
      final tried = <String>[];
      final result = await _run([const _Server('a'), const _Server('b')], (
        s,
      ) async {
        tried.add(s.url);
        return s.url;
      });

      expect(result, 'a');
      expect(tried, ['a']);
    });

    test('advances past a transient failure', () async {
      final tried = <String>[];
      final result = await _run([const _Server('a'), const _Server('b')], (
        s,
      ) async {
        tried.add(s.url);
        if (s.url == 'a') throw Exception('timeout');
        return s.url;
      });

      expect(result, 'b');
      expect(tried, ['a', 'b']);
    });

    test(
      'throws AllElectrumServersFailedException capturing url + isCustom',
      () async {
        await expectLater(
          _run([
            const _Server('a', isCustom: true),
            const _Server('b', isCustom: true),
          ], (_) async => throw Exception('down')),
          throwsA(
            isA<AllElectrumServersFailedException>()
                .having((e) => e.attempts.length, 'attempts', 2)
                .having(
                  (e) => e.attempts.every((a) => a.isCustom),
                  'all custom',
                  true,
                )
                .having(
                  (e) => e.triedCustomServers,
                  'triedCustomServers',
                  true,
                ),
          ),
        );
      },
    );

    test('rethrows a permanent error immediately', () async {
      final tried = <String>[];
      await expectLater(
        _run([const _Server('a'), const _Server('b')], (s) async {
          tried.add(s.url);
          throw const FormatException('bad');
        }, isTransient: (_) => false),
        throwsA(isA<FormatException>()),
      );
      expect(tried, ['a']);
    });
  });
}
