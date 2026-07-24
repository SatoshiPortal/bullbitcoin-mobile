import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

class _MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockPayjoinRepository payjoinRepository;
  late _MockBitcoinWalletRepository bitcoinWalletRepository;
  late _MockSettingsRepository settingsRepository;
  late SendWithPayjoinUsecase usecase;

  final sender =
      Payjoin.sender(
            uri: 'bitcoin:tb1qtest?pj=https://payjo.in/x',
            isTestnet: true,
            walletId: 'w1',
            originalPsbt: 'signed-psbt',
            originalTxId: 'a' * 64,
            amountSat: 10000,
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026, 1, 2),
          )
          as PayjoinSender;

  setUp(() {
    payjoinRepository = _MockPayjoinRepository();
    bitcoinWalletRepository = _MockBitcoinWalletRepository();
    settingsRepository = _MockSettingsRepository();
    usecase = SendWithPayjoinUsecase(
      payjoinRepository: payjoinRepository,
      bitcoinWalletRepository: bitcoinWalletRepository,
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
      () => bitcoinWalletRepository.signPsbt(
        any(),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => 'signed-psbt');
    when(
      () => payjoinRepository.createPayjoinSender(
        walletId: any(named: 'walletId'),
        isTestnet: any(named: 'isTestnet'),
        bip21: any(named: 'bip21'),
        originalPsbt: any(named: 'originalPsbt'),
        amountSat: any(named: 'amountSat'),
        networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
        expireAfterSec: any(named: 'expireAfterSec'),
      ),
    ).thenAnswer((_) async => sender);
  });

  Future<PayjoinSender> callUsecase({int? expireAfterSec}) => usecase.execute(
    walletId: 'w1',
    isTestnet: true,
    bip21: 'bitcoin:tb1qtest?pj=https://payjo.in/x',
    unsignedOriginalPsbt: 'unsigned-psbt',
    amountSat: 10000,
    networkFeesSatPerVb: 2,
    expireAfterSec: expireAfterSec,
  );

  test('creates the session with the user-configured expiry from settings — '
      'resolved inside the usecase, mirroring the receive side, so callers '
      'cannot drift', () async {
    await callUsecase();

    verify(
      () => payjoinRepository.createPayjoinSender(
        walletId: 'w1',
        isTestnet: true,
        bip21: any(named: 'bip21'),
        originalPsbt: 'signed-psbt',
        amountSat: 10000,
        networkFeesSatPerVb: 2,
        expireAfterSec: 3600,
      ),
    ).called(1);
  });

  test('an explicit expiry override wins over the settings value', () async {
    await callUsecase(expireAfterSec: 120);

    verify(
      () => payjoinRepository.createPayjoinSender(
        walletId: any(named: 'walletId'),
        isTestnet: any(named: 'isTestnet'),
        bip21: any(named: 'bip21'),
        originalPsbt: any(named: 'originalPsbt'),
        amountSat: any(named: 'amountSat'),
        networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
        expireAfterSec: 120,
      ),
    ).called(1);
  });
}
