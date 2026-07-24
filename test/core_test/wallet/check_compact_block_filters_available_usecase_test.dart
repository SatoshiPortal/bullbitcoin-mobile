import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

SettingsEntity _buildSettings({
  bool? isDevModeEnabled,
  bool useTorProxy = false,
}) {
  return SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    isDevModeEnabled: isDevModeEnabled,
    useTorProxy: useTorProxy,
  );
}

void main() {
  late _MockSettingsRepository settingsRepository;
  late CheckCompactBlockFiltersAvailableUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    usecase = CheckCompactBlockFiltersAvailableUsecase(
      settingsRepository: settingsRepository,
    );
  });

  // `flutter test` always runs with ENABLE_CBF unset (false) and
  // dart.vm.product false (it is neither a --release build nor built with
  // --dart-define=ENABLE_CBF=true), so every case below exercises the
  // settings-driven half of the gate — the compile-time half
  // (`enableCbfFlag`, `_isProductionBuild`) is fixed for the whole test
  // binary and is documented, not re-derived, by the assertion on
  // `enableCbfFlag` itself.
  test('enableCbfFlag is false by default (no --dart-define=ENABLE_CBF=true '
      'was passed to this test run)', () {
    expect(CheckCompactBlockFiltersAvailableUsecase.enableCbfFlag, isFalse);
  });

  test(
    'available when developer mode is on (non-release test binary)',
    () async {
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _buildSettings(isDevModeEnabled: true));

      expect(await usecase.execute(), isTrue);
    },
  );

  test('unavailable when developer mode is off', () async {
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _buildSettings(isDevModeEnabled: false));

    expect(await usecase.execute(), isFalse);
  });

  test('unavailable when developer mode was never set (null)', () async {
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _buildSettings());

    expect(await usecase.execute(), isFalse);
  });

  test('Tor does not discard an available CBF selection', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => _buildSettings(isDevModeEnabled: true, useTorProxy: true),
    );

    expect(await usecase.execute(), isTrue);
  });
}
