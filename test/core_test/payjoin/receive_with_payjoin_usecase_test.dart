import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

PayjoinReceiver _receiver() =>
    Payjoin.receiver(
          id: 'r1',
          isTestnet: false,
          walletId: 'w1',
          pjUri: 'bitcoin:bc1qtest?pj=https://payjo.in',
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
        )
        as PayjoinReceiver;

void main() {
  late _MockPayjoinRepository payjoinRepository;
  late _MockSettingsRepository settingsRepository;
  late ReceiveWithPayjoinUsecase usecase;

  setUpAll(() {
    registerFallbackValue(BigInt.zero);
  });

  setUp(() {
    payjoinRepository = _MockPayjoinRepository();
    settingsRepository = _MockSettingsRepository();
    usecase = ReceiveWithPayjoinUsecase(
      payjoinRepository: payjoinRepository,
      settingsRepository: settingsRepository,
    );
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        payjoinExpireAfterSec: 120,
      ),
    );
    when(
      () => payjoinRepository.createPayjoinReceiver(
        walletId: any(named: 'walletId'),
        isTestnet: any(named: 'isTestnet'),
        address: any(named: 'address'),
        maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
        expireAfterSec: any(named: 'expireAfterSec'),
      ),
    ).thenAnswer((_) async => _receiver());
  });

  test('falls back to the configured session expiry from settings when no '
      'explicit expireAfterSec is given', () async {
    await usecase.execute(walletId: 'w1', address: 'bc1qtest');

    verify(
      () => payjoinRepository.createPayjoinReceiver(
        walletId: 'w1',
        isTestnet: false,
        address: 'bc1qtest',
        maxFeeRateSatPerVb: BigInt.from(10000),
        expireAfterSec: 120,
      ),
    ).called(1);
  });

  test('an explicit expireAfterSec overrides the settings value', () async {
    await usecase.execute(
      walletId: 'w1',
      address: 'bc1qtest',
      expireAfterSec: 30,
    );

    verify(
      () => payjoinRepository.createPayjoinReceiver(
        walletId: 'w1',
        isTestnet: false,
        address: 'bc1qtest',
        maxFeeRateSatPerVb: BigInt.from(10000),
        expireAfterSec: 30,
      ),
    ).called(1);
  });
}
