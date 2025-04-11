import 'package:bb_mobile/core/settings/data/repository/settings_repository_impl.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockKeyValueStorage extends Mock
    implements KeyValueStorageDatasource<String> {}

void main() {
  late SettingsRepositoryImpl repository;
  late MockKeyValueStorage mockStorage;

  setUp(() {
    mockStorage = MockKeyValueStorage();
    repository = SettingsRepositoryImpl(storage: mockStorage);
  });

  group('SettingsRepository - Environment', () {
    test('setEnvironment saves value correctly', () async {
      const environment = Environment.testnet;

      when(
        () => mockStorage.saveValue(
          key: 'environment',
          value: environment.name,
        ),
      ).thenAnswer((_) async {});

      await repository.setEnvironment(environment);

      verify(
        () => mockStorage.saveValue(
          key: 'environment',
          value: environment.name,
        ),
      ).called(1);
    });

    test('getEnvironment returns saved value', () async {
      when(() => mockStorage.getValue('environment'))
          .thenAnswer((_) async => Environment.testnet.name);

      final result = await repository.getEnvironment();

      expect(result, Environment.testnet);
    });

    test('getEnvironment returns default mainnet when storage is null',
        () async {
      when(() => mockStorage.getValue('environment'))
          .thenAnswer((_) async => null);

      final result = await repository.getEnvironment();

      expect(result, Environment.mainnet);
    });
  });

  group('SettingsRepository - Bitcoin Unit', () {
    test('setBitcoinUnit saves value correctly', () async {
      const bitcoinUnit = BitcoinUnit.sats;

      when(
        () => mockStorage.saveValue(
          key: 'bitcoinUnit',
          value: bitcoinUnit.name,
        ),
      ).thenAnswer((_) async {});

      await repository.setBitcoinUnit(bitcoinUnit);

      verify(
        () => mockStorage.saveValue(
          key: 'bitcoinUnit',
          value: bitcoinUnit.name,
        ),
      ).called(1);
    });

    test('getBitcoinUnit returns saved value', () async {
      when(() => mockStorage.getValue('bitcoinUnit'))
          .thenAnswer((_) async => BitcoinUnit.sats.name);

      final result = await repository.getBitcoinUnit();

      expect(result, BitcoinUnit.sats);
    });

    test('getBitcoinUnit returns default BTC when storage is null', () async {
      when(() => mockStorage.getValue('bitcoinUnit'))
          .thenAnswer((_) async => null);

      final result = await repository.getBitcoinUnit();

      expect(result, BitcoinUnit.btc);
    });
  });

  group('SettingsRepository - Language', () {
    test('setLanguage saves value correctly', () async {
      const language = Language.unitedStatesEnglish;

      when(
        () => mockStorage.saveValue(
          key: 'language',
          value: language.name,
        ),
      ).thenAnswer((_) async {});

      await repository.setLanguage(language);

      verify(
        () => mockStorage.saveValue(
          key: 'language',
          value: language.name,
        ),
      ).called(1);
    });

    test('getLanguage returns saved value', () async {
      when(() => mockStorage.getValue('language'))
          .thenAnswer((_) async => Language.canadianFrench.name);

      final result = await repository.getLanguage();

      expect(result, Language.canadianFrench);
    });

    test('getLanguage returns null when no language is set in storage',
        () async {
      when(() => mockStorage.getValue('language'))
          .thenAnswer((_) async => null);

      final result = await repository.getLanguage();

      expect(result, isNull);
    });
  });
}
