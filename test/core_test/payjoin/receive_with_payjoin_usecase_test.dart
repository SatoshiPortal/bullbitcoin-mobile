import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  setUpAll(() => registerFallbackValue(BigInt.zero));

  late _MockPayjoinRepository payjoinRepository;
  late _MockSettingsRepository settingsRepository;
  late ReceiveWithPayjoinUsecase usecase;

  final receiver =
      Payjoin.receiver(
            id: 'r1',
            isTestnet: true,
            walletId: 'w1',
            pjUri: 'bitcoin:tb1qtest?pj=https://payjo.in/x',
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026, 1, 2),
          )
          as PayjoinReceiver;

  setUp(() {
    payjoinRepository = _MockPayjoinRepository();
    settingsRepository = _MockSettingsRepository();
    usecase = ReceiveWithPayjoinUsecase(
      payjoinRepository: payjoinRepository,
      settingsRepository: settingsRepository,
    );

    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        isPayjoinEnabled: true,
        payjoinExpireAfterSec: 3600,
      ),
    );
    when(
      () => payjoinRepository.createPayjoinReceiver(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        isTestnet: any(named: 'isTestnet'),
        maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
        expireAfterSec: any(named: 'expireAfterSec'),
      ),
    ).thenAnswer((_) async => receiver);
  });

  test(
    'creates the session with the user-configured expiry from settings',
    () async {
      await usecase.execute(walletId: 'w1', address: 'tb1qtest');

      verify(
        () => payjoinRepository.createPayjoinReceiver(
          walletId: 'w1',
          address: 'tb1qtest',
          isTestnet: true,
          maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
          expireAfterSec: 3600,
        ),
      ).called(1);
    },
  );

  test('an explicit expiry override wins over the settings value', () async {
    await usecase.execute(
      walletId: 'w1',
      address: 'tb1qtest',
      expireAfterSec: 120,
    );

    verify(
      () => payjoinRepository.createPayjoinReceiver(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        isTestnet: any(named: 'isTestnet'),
        maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
        expireAfterSec: 120,
      ),
    ).called(1);
  });
}
