import 'package:primitives/primitives.dart' show Ok;
import 'package:bb_mobile/features/autoswap/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/save_autoswap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Err;
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/autoswap/data/auto_swap_settings_repository_impl.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
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
        throwsA(isA<AutoswapNetworkUnavailableException>()),
      );
      final usecase = SaveAutoswapSettingsUsecase(
        saveAutoSwapSettingsUsecase: SaveAutoSwapSettingsUsecase(
          repository: repository,
        ),
      );
      expect(
        await usecase.execute(const AutoSwap(enabled: false)),
        isA<Err>().having(
          (result) => result.failure,
          'failure',
          isA<AutoswapUnsupportedNetworkFailure>(),
        ),
      );
      when(settingsRepository.fetch)
          .thenAnswer((_) async => Ok(_settings(Environment.mainnet)));
      expect(await repository.getAutoSwapParams(), saved);
    },
  );
}
