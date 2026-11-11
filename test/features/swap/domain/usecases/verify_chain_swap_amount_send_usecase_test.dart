import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/swap/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:boltz_swaps/boltz_swaps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

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
  late _MockWalletRepository wallets;
  late VerifyChainSwapAmountSendUsecase usecase;

  void stubSent(int amount) => when(
    () => wallets.getAmountSentToAddress(
      psbtOrPset: 'psbt',
      address: 'bc1plockup',
      walletId: 'w',
    ),
  ).thenAnswer((_) async => amount);

  setUp(() {
    wallets = _MockWalletRepository();
    usecase = VerifyChainSwapAmountSendUsecase(walletRepository: wallets);
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
