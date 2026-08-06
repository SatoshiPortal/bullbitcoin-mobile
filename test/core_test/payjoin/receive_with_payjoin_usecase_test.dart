import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockFeesRepository extends Mock implements FeesRepository {}

FeeOptions _feesAt(double satPerVb) => FeeOptions(
  fastest: NetworkFee.relativeFromSatPerVbyte(satPerVb),
  economic: NetworkFee.relativeFromSatPerVbyte(satPerVb / 2),
  slow: NetworkFee.relativeFromSatPerVbyte(satPerVb / 4),
  minRelay: NetworkFee.relativeFromSatPerVbyte(1),
);

void main() {
  setUpAll(() {
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(Network.bitcoinMainnet);
  });

  late _MockPayjoinRepository payjoinRepository;
  late _MockSettingsRepository settingsRepository;
  late _MockFeesRepository feesRepository;
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
    feesRepository = _MockFeesRepository();
    usecase = ReceiveWithPayjoinUsecase(
      payjoinRepository: payjoinRepository,
      settingsRepository: settingsRepository,
      feesRepository: feesRepository,
    );

    when(
      () => feesRepository.getNetworkFees(network: any(named: 'network')),
    ).thenAnswer((_) async => _feesAt(10));

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

  group('receiver max effective fee rate', () {
    Future<BigInt> capturedMaxFeeRate() async {
      await usecase.execute(walletId: 'w1', address: 'tb1qtest');
      return verify(
            () => payjoinRepository.createPayjoinReceiver(
              walletId: any(named: 'walletId'),
              address: any(named: 'address'),
              isTestnet: any(named: 'isTestnet'),
              maxFeeRateSatPerVb: captureAny(named: 'maxFeeRateSatPerVb'),
              expireAfterSec: any(named: 'expireAfterSec'),
            ),
          ).captured.single
          as BigInt;
    }

    test('tracks the live fastest rate times the multiplier', () async {
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => _feesAt(10));

      expect(await capturedMaxFeeRate(), BigInt.from(30));
    });

    test('never drops below the floor on a quiet mempool', () async {
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => _feesAt(1));

      expect(
        await capturedMaxFeeRate(),
        BigInt.from(PayjoinConstants.minMaxFeeRateSatPerVb),
      );
    });

    test(
      'never exceeds the hard ceiling however high the fee API goes',
      () async {
        // A hostile or broken mempool server is user-configurable input.
        when(
          () => feesRepository.getNetworkFees(network: any(named: 'network')),
        ).thenAnswer((_) async => _feesAt(100000));

        expect(
          await capturedMaxFeeRate(),
          BigInt.from(PayjoinConstants.maxMaxFeeRateSatPerVb),
        );
      },
    );

    test('falls back to the floor when the fee lookup fails', () async {
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenThrow(Exception('mempool unreachable'));

      expect(
        await capturedMaxFeeRate(),
        BigInt.from(PayjoinConstants.minMaxFeeRateSatPerVb),
      );
    });

    test('is never the old hardcoded 10000 sat/vB', () async {
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => _feesAt(500));

      expect(await capturedMaxFeeRate(), lessThan(BigInt.from(10000)));
    });
  });
}
