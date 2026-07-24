import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_model.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsDatasource extends Mock implements SettingsDatasource {}

SettingsModel _buildModel({bool useCompactBlockFiltersByDefault = false}) {
  return SettingsModel(
    id: 1,
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    language: Language.unitedStatesEnglish,
    currency: 'USD',
    hideAmounts: false,
    isSuperuser: false,
    isDevModeEnabled: false,
    useTorProxy: false,
    torProxyPort: 9050,
    themeMode: AppThemeMode.system,
    isErrorReportingEnabled: false,
    useCompactBlockFiltersByDefault: useCompactBlockFiltersByDefault,
  );
}

void main() {
  late _MockSettingsDatasource datasource;
  late SettingsRepository repository;

  setUp(() {
    datasource = _MockSettingsDatasource();
    repository = SettingsRepository(settingsDatasource: datasource);
  });

  group('fetch', () {
    test(
      'maps useCompactBlockFiltersByDefault: false through to the entity',
      () async {
        when(() => datasource.fetch()).thenAnswer((_) async => _buildModel());

        final entity = await repository.fetch();

        expect(entity.useCompactBlockFiltersByDefault, isFalse);
      },
    );

    test(
      'maps useCompactBlockFiltersByDefault: true through to the entity',
      () async {
        when(() => datasource.fetch()).thenAnswer(
          (_) async => _buildModel(useCompactBlockFiltersByDefault: true),
        );

        final entity = await repository.fetch();

        expect(entity.useCompactBlockFiltersByDefault, isTrue);
      },
    );
  });

  group('setUseCompactBlockFiltersByDefault', () {
    test('forwards true to the datasource', () async {
      when(
        () => datasource.setUseCompactBlockFiltersByDefault(any()),
      ).thenAnswer((_) async {});

      await repository.setUseCompactBlockFiltersByDefault(true);

      verify(
        () => datasource.setUseCompactBlockFiltersByDefault(true),
      ).called(1);
    });

    test('forwards false to the datasource', () async {
      when(
        () => datasource.setUseCompactBlockFiltersByDefault(any()),
      ).thenAnswer((_) async {});

      await repository.setUseCompactBlockFiltersByDefault(false);

      verify(
        () => datasource.setUseCompactBlockFiltersByDefault(false),
      ).called(1);
    });
  });

  group('setUseTorProxy', () {
    test(
      'persists to the datasource and emits on torProxyChangeStream',
      () async {
        when(() => datasource.setUseTorProxy(any())).thenAnswer((_) async {});

        final emitted = <bool>[];
        final subscription = repository.torProxyChangeStream.listen(
          emitted.add,
        );

        await repository.setUseTorProxy(true);
        // Let the broadcast stream's listener actually receive the event.
        await Future<void>.delayed(Duration.zero);

        verify(() => datasource.setUseTorProxy(true)).called(1);
        expect(emitted, [true]);

        await subscription.cancel();
      },
    );

    test('close() closes torProxyChangeStream', () async {
      await repository.close();

      await expectLater(repository.torProxyChangeStream, emitsDone);
    });
  });
}
