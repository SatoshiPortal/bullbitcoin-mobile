import 'package:primitives/primitives.dart' show BitcoinUnit, Ok;
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart'
    show AutoSwap, BoltzSwapsDatabase, SwapsUnsupportedNetworkFailure;
import 'package:swaps/src/data/auto_swap_settings_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements Preferences {}

SettingsEntity _settings(Environment environment) => SettingsEntity(
  environment: environment,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);

void main() {
  late BoltzSwapsDatabase database;
  late _MockSettingsRepository settingsRepository;
  late AutoSwapSettingsRepositoryImpl repository;

  setUp(() {
    database = BoltzSwapsDatabase(NativeDatabase.memory());
    settingsRepository = _MockSettingsRepository();
    repository = AutoSwapSettingsRepositoryImpl(database, settingsRepository);
  });

  tearDown(() => database.close());

  test('a persisted row that breaks a rule still loads', () async {
    when(settingsRepository.fetch)
        .thenAnswer((_) async => Ok(_settings(Environment.mainnet)));
    const legacy = AutoSwap(
      balanceThresholdSats: 10000,
      triggerBalanceSats: 15000,
      feeThresholdPercent: 50,
    );
    await repository.updateAutoSwapParams(legacy);
    final loaded = await repository.getAutoSwapParams();
    expect(loaded, legacy);
    expect(loaded.violation, isNotNull);
  });

  test('keeps mainnet and testnet settings independent', () async {
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => Ok(_settings(Environment.mainnet)));
    const mainnet = AutoSwap(enabled: false, balanceThresholdSats: 111111);
    await repository.updateAutoSwapParams(mainnet);

    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => Ok(_settings(Environment.testnet)));
    const testnet = AutoSwap(enabled: false, balanceThresholdSats: 222222);
    await repository.updateAutoSwapParams(testnet);

    expect(await repository.getAutoSwapParams(), testnet);
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => Ok(_settings(Environment.mainnet)));
    expect(await repository.getAutoSwapParams(), mainnet);
  });
  test(
    'regtest cannot read or overwrite either historical settings row',
    () async {
      when(settingsRepository.fetch)
          .thenAnswer((_) async => Ok(_settings(Environment.mainnet)));
      const saved = AutoSwap(enabled: false, balanceThresholdSats: 111111);
      await repository.updateAutoSwapParams(saved);
      when(settingsRepository.fetch)
          .thenAnswer((_) async => Ok(_settings(Environment.regtest)));
      await expectLater(
        repository.getAutoSwapParams(),
        throwsA(isA<SwapsUnsupportedNetworkFailure>()),
      );
      await expectLater(
        repository.updateAutoSwapParams(const AutoSwap(enabled: false)),
        throwsA(isA<SwapsUnsupportedNetworkFailure>()),
      );
      when(settingsRepository.fetch)
          .thenAnswer((_) async => Ok(_settings(Environment.mainnet)));
      expect(await repository.getAutoSwapParams(), saved);
    },
  );
}
