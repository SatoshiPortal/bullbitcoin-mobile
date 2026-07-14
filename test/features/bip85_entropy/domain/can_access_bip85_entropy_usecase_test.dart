import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/can_access_bip85_entropy_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

void main() {
  late _MockGetSettingsUsecase getSettings;
  late CanAccessBip85EntropyUsecase usecase;

  setUp(() {
    getSettings = _MockGetSettingsUsecase();
    usecase = CanAccessBip85EntropyUsecase(getSettings: getSettings);
  });

  test(
    'permits access only when superuser and developer mode are true',
    () async {
      when(
        getSettings.execute,
      ).thenAnswer((_) async => _settings(isSuperuser: true, isDevMode: true));

      expect(await usecase.execute(), isTrue);
    },
  );

  test('denies every false or unknown flag combination', () async {
    for (final flags in <({bool? isSuperuser, bool? isDevMode})>[
      (isSuperuser: false, isDevMode: true),
      (isSuperuser: true, isDevMode: false),
      (isSuperuser: false, isDevMode: false),
      (isSuperuser: null, isDevMode: true),
      (isSuperuser: true, isDevMode: null),
      (isSuperuser: null, isDevMode: null),
    ]) {
      reset(getSettings);
      when(getSettings.execute).thenAnswer(
        (_) async => _settings(
          isSuperuser: flags.isSuperuser,
          isDevMode: flags.isDevMode,
        ),
      );

      expect(
        await usecase.execute(),
        isFalse,
        reason: 'flags=$flags must fail closed',
      );
    }
  });

  test('fails closed when settings cannot be loaded', () async {
    when(getSettings.execute).thenThrow(StateError('settings unavailable'));

    expect(await usecase.execute(), isFalse);
  });
}

SettingsEntity _settings({bool? isSuperuser, bool? isDevMode}) {
  return SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevMode,
  );
}
