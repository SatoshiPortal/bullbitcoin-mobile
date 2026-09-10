import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/sign_sell_payin_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

/// A signing error quotes the descriptor, which contains an xpub.
const _rawReason = 'BdkError: cannot sign wpkh([aabbccdd]xpub6Secret/0/*)';

void main() {
  late _MockBitcoinWalletRepository bitcoin;
  late _MockLiquidWalletRepository liquid;
  late SignSellPayinUsecase usecase;

  setUp(() {
    bitcoin = _MockBitcoinWalletRepository();
    liquid = _MockLiquidWalletRepository();
    usecase = SignSellPayinUsecase(
      bitcoinWalletRepository: bitcoin,
      liquidWalletRepository: liquid,
    );
  });

  group('bitcoin', () {
    test('returns the signed psbt with its vsize', () async {
      when(
        () => bitcoin.signPsbt(any(), walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => 'signed-psbt');
      when(
        () => bitcoin.getTxSize(psbt: any(named: 'psbt')),
      ).thenAnswer((_) async => 110);

      final result = await usecase.bitcoin(
        psbt: 'unsigned',
        walletId: 'wallet-1',
      );

      final value =
          (result as Ok<({String signedPsbt, int txSize}), SellFailure>).value;
      expect(value.signedPsbt, 'signed-psbt');
      expect(value.txSize, 110);
    });

    test(
      'sanitizes a signing error, keeping the reason for logs only',
      () async {
        when(
          () => bitcoin.signPsbt(any(), walletId: any(named: 'walletId')),
        ).thenThrow(Exception(_rawReason));

        final result = await usecase.bitcoin(
          psbt: 'unsigned',
          walletId: 'wallet-1',
        );

        switch (result) {
          case Ok():
            fail('a failed signature must not yield a transaction');
          case Err(:final failure):
            expect(failure, isA<SellUnexpectedFailure>());
            expect(failure.logMessage, contains('xpub6Secret'));
        }
      },
    );
  });

  group('liquid', () {
    test('returns the signed pset', () async {
      when(
        () => liquid.signPset(
          pset: any(named: 'pset'),
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => 'signed-pset');

      final result = await usecase.liquid(
        pset: 'unsigned',
        walletId: 'wallet-1',
      );

      expect((result as Ok<String, SellFailure>).value, 'signed-pset');
    });

    test('sanitizes a signing error', () async {
      when(
        () => liquid.signPset(
          pset: any(named: 'pset'),
          walletId: any(named: 'walletId'),
        ),
      ).thenThrow(Exception(_rawReason));

      final result = await usecase.liquid(
        pset: 'unsigned',
        walletId: 'wallet-1',
      );

      expect(
        (result as Err<String, SellFailure>).failure,
        isA<SellUnexpectedFailure>(),
      );
    });
  });
}
