import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/get_sweep_display_settings_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

class _MockConvertSatsToCurrency extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

void main() {
  late _MockGetSettings getSettings;
  late _MockConvertSatsToCurrency convert;
  late GetSweepDisplaySettingsUsecase usecase;

  setUp(() {
    getSettings = _MockGetSettings();
    convert = _MockConvertSatsToCurrency();
    usecase = GetSweepDisplaySettingsUsecase(
      getSettingsUsecase: getSettings,
      convertSatsToCurrencyAmountUsecase: convert,
    );
  });

  test(
    'returns privacy and denomination preferences with the fiat hint',
    () async {
      const settings = SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
        hideAmounts: false,
      );
      when(() => getSettings.execute()).thenAnswer((_) async => settings);
      when(
        () => convert.execute(
          amountSat: BigInt.from(100000000),
          currencyCode: 'CAD',
        ),
      ).thenAnswer((_) async => 42000);

      final result = await usecase.execute();

      final value = (result as Ok<SweepDisplaySettings, SweepFailure>).value;
      expect(value.bitcoinUnit, BitcoinUnit.sats);
      expect(value.hideAmounts, isFalse);
      expect(value.exchangeRate, 42000);
      expect(value.fiatCurrencyCode, 'CAD');
    },
  );

  test('defaults missing hide-amounts preference to private', () async {
    const settings = SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.btc,
      currencyCode: 'USD',
    );
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    when(
      () => convert.execute(
        amountSat: BigInt.from(100000000),
        currencyCode: 'USD',
      ),
    ).thenAnswer((_) async => 1);

    final result = await usecase.execute();

    expect(
      (result as Ok<SweepDisplaySettings, SweepFailure>).value.hideAmounts,
      isTrue,
    );
  });

  test('keeps display preferences when the fiat hint is unavailable', () async {
    const settings = SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      hideAmounts: false,
    );
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    when(
      () => convert.execute(
        amountSat: BigInt.from(100000000),
        currencyCode: 'CAD',
      ),
    ).thenThrow(Exception('rate offline'));

    final result = await usecase.execute();

    final value = (result as Ok<SweepDisplaySettings, SweepFailure>).value;
    expect(value.bitcoinUnit, BitcoinUnit.sats);
    expect(value.hideAmounts, isFalse);
    expect(value.exchangeRate, 0);
  });

  test('maps display lookup exceptions without blocking the cubit', () async {
    when(() => getSettings.execute()).thenThrow(Exception('storage offline'));

    final result = await usecase.execute();

    expect(result, isA<Err<SweepDisplaySettings, SweepFailure>>());
    expect(
      (result as Err<SweepDisplaySettings, SweepFailure>).failure,
      isA<SweepUnexpectedFailure>(),
    );
  });
}
