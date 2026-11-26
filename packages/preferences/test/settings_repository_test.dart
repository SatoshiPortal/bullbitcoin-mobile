import 'dart:async';

import 'package:preferences/preferences.dart' show Preferences;
import 'package:preferences/testing.dart';
import 'package:preferences/src/domain/settings_entity.dart';
import 'package:preferences/src/domain/preferences_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The shape drift produces: the failing statement, which can embed values.
const _rawReason =
    'SqliteException(787): FOREIGN KEY constraint failed, '
    'UPDATE settings SET currency = "CAD" WHERE id = 1';

/// The failure an [Err] carries, typed by the [Result]; an [Ok] fails the test.
F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

class _MockDatasource extends Mock implements PreferencesDao {}

void main() {
  setUpAll(() {
    registerFallbackValue(BitcoinUnit.btc);
    registerFallbackValue(Environment.mainnet);
    registerFallbackValue(Language.unitedStatesEnglish);
  });

  late _MockDatasource datasource;

  Preferences build() => PreferencesTesting.fromDao(datasource);

  setUp(() => datasource = _MockDatasource());

  group('write failures are sanitized', () {
    test('a throwing datasource becomes a typed failure', () async {
      when(() => datasource.setCurrency(any()))
          .thenThrow(Exception(_rawReason));

      final result = await build().setCurrency('CAD');
      final failure = _failureOf(result);

      expect(failure, isA<PreferencesWriteFailure>());
      expect(
        failure.logMessage,
        isNot(contains('SqliteException')),
        reason: 'the failing statement must not travel in the failure',
      );
      expect(failure.logMessage, isNot(contains('UPDATE settings')));
    });

    test('a clean write is Ok', () async {
      when(() => datasource.setCurrency(any())).thenAnswer((_) async {});

      expect(
        await build().setCurrency('CAD'),
        isA<Ok<void, PreferencesFailure>>(),
      );
    });

    // Every setter shares the boundary; spot-check the rest rather than the
    // whole 16, since they are generated from one shape.
    test('the other setters are sanitized too', () async {
      when(() => datasource.setBitcoinUnit(any()))
          .thenThrow(Exception(_rawReason));
      when(() => datasource.setLanguage(any()))
          .thenThrow(Exception(_rawReason));
      when(() => datasource.setHideAmounts(any()))
          .thenThrow(Exception(_rawReason));

      final repository = build();
      for (final result in [
        await repository.setBitcoinUnit(BitcoinUnit.sats),
        await repository.setLanguage(Language.unitedStatesEnglish),
        await repository.setHideAmounts(true),
      ]) {
        final failure = _failureOf(result);
        expect(failure, isA<PreferencesWriteFailure>());
        expect(failure.logMessage, isNot(contains('SqliteException')));
      }
    });
  });

  group('a persisted write is never reported as failed', () {
    // The stream announcement and the Sentry mirror are side effects of a
    // write that already succeeded. Letting them decide Ok/Err would tell the
    // user their setting was lost when the database kept it.
    test('a closed currency stream does not fail the write', () async {
      when(() => datasource.setCurrency(any())).thenAnswer((_) async {});
      final repository = build();
      await repository.close();

      expect(
        await repository.setCurrency('EUR'),
        isA<Ok<void, PreferencesFailure>>(),
      );
    });
  });

  group('currency change stream', () {
    // The stream is what other features listen to; it must not announce a
    // change that did not persist.
    test('a failed write does not emit a currency change', () async {
      when(() => datasource.setCurrency(any()))
          .thenThrow(Exception(_rawReason));
      final repository = build();
      final seen = <String>[];
      final sub = repository.currencyChangeStream.listen(
        (result) => seen.add(
          result.fold(
            (value) => value,
            (failure) => fail('Unexpected failure: $failure'),
          ),
        ),
      );
      addTearDown(sub.cancel);

      expect(await repository.setCurrency('CAD'), isA<Err>());
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
    });

    test('a successful write emits the new currency', () async {
      when(() => datasource.setCurrency(any())).thenAnswer((_) async {});
      final repository = build();
      final seen = <String>[];
      final sub = repository.currencyChangeStream.listen(
        (result) => seen.add(
          result.fold(
            (value) => value,
            (failure) => fail('Unexpected failure: $failure'),
          ),
        ),
      );
      addTearDown(sub.cancel);

      expect(await repository.setCurrency('EUR'), isA<Ok>());
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['EUR']);
    });
  });

  group('environment change stream', () {
    test('network transitions invalidate before a pending write', () async {
      final gate = Completer<void>();
      when(() => datasource.setEnvironment(any()))
          .thenAnswer((_) => gate.future);
      final repository = build();
      final seen = <bool>[];
      final sub = repository.environmentTransitions.listen(seen.add);
      addTearDown(sub.cancel);
      final write = repository.setEnvironment(Environment.testnet);
      expect(repository.isEnvironmentChanging, isTrue);
      expect(seen, [true]);
      gate.complete();
      expect(await write, isA<Ok>());
      expect(repository.isEnvironmentChanging, isFalse);
      expect(seen, [true, false]);
    });

    test('failed network writes release the transition gate', () async {
      when(() => datasource.setEnvironment(any()))
          .thenThrow(Exception('failed'));
      final repository = build();
      final seen = <bool>[];
      final sub = repository.environmentTransitions.listen(seen.add);
      addTearDown(sub.cancel);
      expect(await repository.setEnvironment(Environment.testnet), isA<Err>());
      expect(repository.isEnvironmentChanging, isFalse);
      expect(seen, [true, false]);
    });

    test('overlapping writes keep the transition gate closed', () async {
      final first = Completer<void>();
      final second = Completer<void>();
      when(() => datasource.setEnvironment(Environment.testnet))
          .thenAnswer((_) => first.future);
      when(() => datasource.setEnvironment(Environment.mainnet))
          .thenAnswer((_) => second.future);
      final repository = build();
      final seen = <bool>[];
      final sub = repository.environmentTransitions.listen(seen.add);
      addTearDown(sub.cancel);
      final firstWrite = repository.setEnvironment(Environment.testnet);
      final secondWrite = repository.setEnvironment(Environment.mainnet);
      first.complete();
      expect(await firstWrite, isA<Ok>());
      expect(repository.isEnvironmentChanging, isTrue);
      second.complete();
      expect(await secondWrite, isA<Ok>());
      expect(repository.isEnvironmentChanging, isFalse);
      expect(seen, [true, true, true, false]);
    });

    test('a successful write emits the new environment', () async {
      when(() => datasource.setEnvironment(any())).thenAnswer((_) async {});
      final repository = build();
      final seen = <Environment>[];
      final sub = repository.environmentChangeStream.listen(
        (result) => seen.add(
          result.fold(
            (value) => value,
            (failure) => fail('Unexpected failure: $failure'),
          ),
        ),
      );
      addTearDown(sub.cancel);

      expect(await repository.setEnvironment(Environment.testnet), isA<Ok>());
      await Future<void>.delayed(Duration.zero);

      expect(seen, [Environment.testnet]);
    });

    test('a failed write does not emit an environment change', () async {
      when(() => datasource.setEnvironment(any()))
          .thenThrow(Exception(_rawReason));
      final repository = build();
      final seen = <Environment>[];
      final sub = repository.environmentChangeStream.listen(
        (result) => seen.add(
          result.fold(
            (value) => value,
            (failure) => fail('Unexpected failure: $failure'),
          ),
        ),
      );
      addTearDown(sub.cancel);

      expect(await repository.setEnvironment(Environment.testnet), isA<Err>());
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
    });
  });
}
