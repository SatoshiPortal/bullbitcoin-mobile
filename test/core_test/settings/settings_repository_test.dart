import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_store_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The shape drift produces: the failing statement, which can embed values.
const _rawReason =
    'SqliteException(787): FOREIGN KEY constraint failed, '
    'UPDATE settings SET currency = "CAD" WHERE id = 1';

class _MockDatasource extends Mock implements SettingsDatasource {}

void main() {
  setUpAll(() {
    registerFallbackValue(BitcoinUnit.btc);
    registerFallbackValue(Language.unitedStatesEnglish);
  });

  late _MockDatasource datasource;

  SettingsRepository build() =>
      SettingsRepository(settingsDatasource: datasource);

  setUp(() => datasource = _MockDatasource());

  group('write failures are sanitized', () {
    test('a throwing datasource becomes a typed failure', () async {
      when(
        () => datasource.setCurrency(any()),
      ).thenThrow(Exception(_rawReason));

      final result = await build().setCurrency('CAD');
      final failure = (result as Err).failure as SettingsStoreFailure;

      expect(failure, isA<SettingsStoreWriteFailure>());
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
        isA<Ok<void, SettingsStoreFailure>>(),
      );
    });

    // Every setter shares the boundary; spot-check the rest rather than the
    // whole 16, since they are generated from one shape.
    test('the other setters are sanitized too', () async {
      when(
        () => datasource.setBitcoinUnit(any()),
      ).thenThrow(Exception(_rawReason));
      when(
        () => datasource.setLanguage(any()),
      ).thenThrow(Exception(_rawReason));
      when(
        () => datasource.setHideAmounts(any()),
      ).thenThrow(Exception(_rawReason));

      final repository = build();
      for (final result in [
        await repository.setBitcoinUnit(BitcoinUnit.sats),
        await repository.setLanguage(Language.unitedStatesEnglish),
        await repository.setHideAmounts(true),
      ]) {
        final failure = (result as Err).failure as SettingsStoreFailure;
        expect(failure, isA<SettingsStoreWriteFailure>());
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
        isA<Ok<void, SettingsStoreFailure>>(),
      );
    });
  });

  group('currency change stream', () {
    // The stream is what other features listen to; it must not announce a
    // change that did not persist.
    test('a failed write does not emit a currency change', () async {
      when(
        () => datasource.setCurrency(any()),
      ).thenThrow(Exception(_rawReason));
      final repository = build();
      final seen = <String>[];
      final sub = repository.currencyChangeStream.listen(seen.add);
      addTearDown(sub.cancel);

      await repository.setCurrency('CAD');
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
    });

    test('a successful write emits the new currency', () async {
      when(() => datasource.setCurrency(any())).thenAnswer((_) async {});
      final repository = build();
      final seen = <String>[];
      final sub = repository.currencyChangeStream.listen(seen.add);
      addTearDown(sub.cancel);

      await repository.setCurrency('EUR');
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['EUR']);
    });
  });
}
