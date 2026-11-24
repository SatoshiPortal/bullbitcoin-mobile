import 'package:spend/legacy_exceptions.dart';
import 'package:bb_mobile/features/send/domain/usecases/read_send_recipient_amount_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:swaps/swaps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientAmount extends Mock
    implements ReadSendRecipientAmountUsecase {}

final _lnSend = Swap.lnSend(
  id: 'lnSendSwap01',
  keyIndex: 0,
  type: SwapType.bitcoinToLightning,
  status: SwapStatus.pending,
  environment: Environment.mainnet,
  creationTime: DateTime.utc(2026),
  sendWalletId: 'w',
  invoice: 'lnbc1',
  paymentAddress: 'bc1plockup',
  paymentAmount: 51000,
);

void main() {
  late _MockRecipientAmount wallets;
  late VerifyChainSwapAmountSendUsecase usecase;

  void stubSent(int amount) => when(
    () => wallets.execute(
      psbtOrPset: 'psbt',
      address: 'bc1plockup',
      walletId: 'w',
    ),
  ).thenAnswer((_) async => amount);

  setUp(() {
    wallets = _MockRecipientAmount();
    usecase = VerifyChainSwapAmountSendUsecase(recipientAmount: wallets);
  });

  test('accepts a lightning lockup that pays exactly the swap', () async {
    stubSent(51000);

    await usecase.execute(psbtOrPset: 'psbt', swap: _lnSend, walletId: 'w');
  });

  test('refuses a lightning lockup that pays a different amount', () async {
    stubSent(50999);

    await expectLater(
      usecase.execute(psbtOrPset: 'psbt', swap: _lnSend, walletId: 'w'),
      throwsA(isA<SwapCreationException>()),
    );
  });

  test('a refusal names no amount', () async {
    stubSent(50999);

    await expectLater(
      usecase.execute(psbtOrPset: 'psbt', swap: _lnSend, walletId: 'w'),
      throwsA(
        isA<SwapCreationException>().having(
          (e) => e.toString(),
          'message',
          allOf(isNot(contains('51000')), isNot(contains('50999'))),
        ),
      ),
    );
  });

  test('refuses a receive swap, which has no lockup of ours', () async {
    final receive = Swap.lnReceive(
      id: 'lnReceive001',
      keyIndex: 0,
      type: SwapType.lightningToBitcoin,
      status: SwapStatus.pending,
      environment: Environment.mainnet,
      creationTime: DateTime.utc(2026),
      receiveWalletId: 'w',
      invoice: 'lnbc1',
    );

    await expectLater(
      usecase.execute(psbtOrPset: 'psbt', swap: receive, walletId: 'w'),
      throwsA(isA<SwapCreationException>()),
    );
    verifyZeroInteractions(wallets);
  });
}
