import 'package:silent/src/data/bwk_sp_backend_probe.dart';
import 'package:silent/src/domain/entities/sp_backend_kind.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('tip probe uses only the configured tip endpoint', () async {
    String? requested;
    final probe = BwkSpBackendProbe(
      tip: ({required url}) async {
        requested = url;
        return 123;
      },
      testBlindbit: ({required url}) async => fail('scan probe called'),
    );
    expect(
      await probe.blindbitTip('https://configured.example'),
      isA<Ok<void, SilentFailure>>(),
    );
    expect(requested, 'https://configured.example');
  });

  test('tip failure does not expose the URL or foreign error', () async {
    final probe = BwkSpBackendProbe(
      tip: ({required url}) async => throw Exception('private detail $url'),
    );
    final result = await probe.blindbitTip('https://private.example');
    final failure = (result as Err<void, SilentFailure>).failure;
    expect(failure, isA<SilentBackendUnreachable>());
    expect(failure.logMessage, isNot(contains('private')));
  });

  test(
    'tip maps a bridge String failure without exposing its contents',
    () async {
      final probe = BwkSpBackendProbe(
        tip: ({required url}) async => throw 'private backend detail $url',
      );
      final result = await probe.blindbitTip('https://private.example');
      final failure = (result as Err<void, SilentFailure>).failure;
      expect(failure, isA<SilentBackendUnreachable>());
      expect(failure.logMessage, isNot(contains('private')));
    },
  );

  test('tip propagates programmer errors', () async {
    final error = StateError('programmer error');
    final probe = BwkSpBackendProbe(tip: ({required url}) async => throw error);
    await expectLater(
      probe.blindbitTip('https://example.com'),
      throwsA(same(error)),
    );
  });

  group('BwkSpBackendProbe.testBackend', () {
    BwkSpBackendProbe build({
      Future<void> Function({required String url})? testBlindbit,
      Future<void> Function({required String url})? testElectrum,
    }) => BwkSpBackendProbe(
      testBlindbit: testBlindbit ?? ({required String url}) async {},
      testElectrum: testElectrum ?? ({required String url}) async {},
    );

    test('blindbit returns Ok on success', () async {
      final probe = build(testBlindbit: ({required String url}) async {});
      final result = await probe.testBackend(
        SpBackendKind.blindbit,
        'http://ok',
      );
      expect(result, isA<Ok<void, SilentFailure>>());
    });

    test('blindbit maps a throw to SilentBackendUnreachable', () async {
      final probe = build(
        testBlindbit: ({required String url}) async => throw Exception('boom'),
      );
      final result = await probe.testBackend(
        SpBackendKind.blindbit,
        'http://bad',
      );
      expect(result, isA<Err<void, SilentFailure>>());
      final failure = (result as Err<void, SilentFailure>).failure;
      expect(failure, isA<SilentBackendUnreachable>());
      expect(failure.logMessage, isNot(contains('boom')));
      expect(failure.logMessage, isNot(contains('http://bad')));
    });

    test('electrum returns Ok on success', () async {
      final probe = build(testElectrum: ({required String url}) async {});
      final result = await probe.testBackend(
        SpBackendKind.electrum,
        'tcp://ok:1',
      );
      expect(result, isA<Ok<void, SilentFailure>>());
    });

    test('electrum maps a throw to SilentBackendUnreachable', () async {
      final probe = build(
        testElectrum: ({required String url}) async =>
            throw Exception('no route'),
      );
      final result = await probe.testBackend(
        SpBackendKind.electrum,
        'tcp://bad:1',
      );
      expect(result, isA<Err<void, SilentFailure>>());
      final failure = (result as Err<void, SilentFailure>).failure;
      expect(failure, isA<SilentBackendUnreachable>());
      expect(failure.logMessage, isNot(contains('no route')));
    });
  });
}
