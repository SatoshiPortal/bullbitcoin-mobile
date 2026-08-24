import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/auto_swap_settings_repository_impl.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

SettingsEntity _settings(Environment environment) => SettingsEntity(
  environment: environment,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);

void main() {
  late SqliteDatabase database;
  late _MockSettingsRepository settingsRepository;
  late AutoSwapSettingsRepositoryImpl repository;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    settingsRepository = _MockSettingsRepository();
    repository = AutoSwapSettingsRepositoryImpl(database, settingsRepository);
  });

  tearDown(() => database.close());

  test('keeps mainnet and testnet settings independent', () async {
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(Environment.mainnet));
    const mainnet = AutoSwap(enabled: false, balanceThresholdSats: 111111);
    await repository.updateAutoSwapParams(mainnet);

    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(Environment.testnet));
    const testnet = AutoSwap(enabled: false, balanceThresholdSats: 222222);
    await repository.updateAutoSwapParams(testnet);

    expect(await repository.getAutoSwapParams(), testnet);
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(Environment.mainnet));
    expect(await repository.getAutoSwapParams(), mainnet);
  });
}
