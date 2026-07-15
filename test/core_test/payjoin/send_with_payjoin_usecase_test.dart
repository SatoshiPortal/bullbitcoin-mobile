import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

class _MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

PayjoinSender _sender() =>
    Payjoin.sender(
          uri: 'bitcoin:bc1qtest?pj=https://payjo.in',
          isTestnet: false,
          walletId: 'w1',
          originalPsbt: 'cHNidP8=',
          originalTxId: 'orig-txid',
          amountSat: 50000,
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
        )
        as PayjoinSender;

void main() {
  late _MockPayjoinRepository payjoinRepository;
  late _MockBitcoinWalletRepository bitcoinWalletRepository;
  late _MockSettingsRepository settingsRepository;
  late SendWithPayjoinUsecase usecase;

  setUp(() {
    payjoinRepository = _MockPayjoinRepository();
    bitcoinWalletRepository = _MockBitcoinWalletRepository();
    settingsRepository = _MockSettingsRepository();
    usecase = SendWithPayjoinUsecase(
      payjoinRepository: payjoinRepository,
      bitcoinWalletRepository: bitcoinWalletRepository,
      settingsRepository: settingsRepository,
    );
    when(
      () => bitcoinWalletRepository.signPsbt(
        any(),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => 'cHNidP9zaWduZWQ=');
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        payjoinExpireAfterSec: 120,
      ),
    );
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
    ).thenAnswer((_) async => _sender());
  });

  test('falls back to the configured session expiry from settings when no '
      'explicit expireAfterSec is given', () async {
    await usecase.execute(
      walletId: 'w1',
      isTestnet: false,
      bip21: 'bitcoin:bc1qtest?pj=https://payjo.in',
      unsignedOriginalPsbt: 'cHNidP9vcmlnaW5hbA==',
      amountSat: 50000,
      networkFeesSatPerVb: 1,
    );

    verify(
      () => payjoinRepository.createPayjoinSender(
        walletId: 'w1',
        isTestnet: false,
        bip21: 'bitcoin:bc1qtest?pj=https://payjo.in',
        originalPsbt: 'cHNidP9zaWduZWQ=',
        amountSat: 50000,
        networkFeesSatPerVb: 1,
        expireAfterSec: 120,
      ),
    ).called(1);
  });

  test('an explicit expireAfterSec overrides the settings value', () async {
    await usecase.execute(
      walletId: 'w1',
      isTestnet: false,
      bip21: 'bitcoin:bc1qtest?pj=https://payjo.in',
      unsignedOriginalPsbt: 'cHNidP9vcmlnaW5hbA==',
      amountSat: 50000,
      networkFeesSatPerVb: 1,
      expireAfterSec: 45,
    );

    verify(
      () => payjoinRepository.createPayjoinSender(
        walletId: 'w1',
        isTestnet: false,
        bip21: 'bitcoin:bc1qtest?pj=https://payjo.in',
        originalPsbt: 'cHNidP9zaWduZWQ=',
        amountSat: 50000,
        networkFeesSatPerVb: 1,
        expireAfterSec: 45,
      ),
    ).called(1);
  });
}
