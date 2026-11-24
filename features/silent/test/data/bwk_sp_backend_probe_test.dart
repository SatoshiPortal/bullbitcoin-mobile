import 'package:silent/src/data/bwk_sp_backend_probe.dart';
import 'package:silent/src/domain/entities/sp_backend_kind.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
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
