import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_exchange_payin_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepository repository;
  late VerifyExchangePayinUsecase usecase;

  setUp(() {
    repository = _MockWalletRepository();
    usecase = VerifyExchangePayinUsecase(repository);
  });

  test('accepts the exact pinned Exchange payin output', () async {
    when(
      () => repository.getAmountSentToAddress(
        psbtOrPset: 'pset',
        address: 'payin-address',
        walletId: 'wallet-1',
      ),
    ).thenAnswer((_) async => 1010);

    await expectLater(
      usecase.execute(
        psbtOrPset: 'pset',
        record: _record(),
        walletId: 'wallet-1',
      ),
      completes,
    );
  });

  test('rejects an amount mismatch before signing', () async {
    when(
      () => repository.getAmountSentToAddress(
        psbtOrPset: 'pset',
        address: 'payin-address',
        walletId: 'wallet-1',
      ),
    ).thenAnswer((_) async => 1009);

    await expectLater(
      usecase.execute(
        psbtOrPset: 'pset',
        record: _record(),
        walletId: 'wallet-1',
      ),
      throwsA(isA<SendTransactionBuildFailure>()),
    );
  });
}

OrderSwapRecord _record() {
  final createdAt = DateTime.utc(2026);
  return OrderSwapRecord(
    localId: 'local-1',
    purpose: OrderSwapPurpose.sendLightning,
    environment: OrderSwapEnvironment.testnet,
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: OrderSwapNetwork.lightning,
    isInAmountFixed: false,
    requestedAmountSat: BigInt.from(1000),
    sourceWalletId: 'wallet-1',
    destination: 'invoice',
    fallback: 'fallback',
    order: OrderSwap(
      orderId: 'order-1',
      orderNumber: 1,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      payinAmountSat: BigInt.from(1010),
      payoutAmountSat: BigInt.from(1000),
      payinCurrency: 'LBTC',
      payoutCurrency: 'BTCLN',
      payinMethod: 'Liquid',
      payoutMethod: 'Lightning',
      orderType: 'Swap',
      orderStatus: 'Awaiting payment',
      payinStatus: 'In progress',
      payoutStatus: 'Not started',
      messageCode: 'ORDER_CREATED',
      liquidAddress: 'payin-address',
      lightningInvoice: 'invoice',
      createdAt: createdAt,
      confirmationDeadline: createdAt.add(const Duration(minutes: 5)),
    ),
    createdAt: createdAt,
    localStatus: OrderSwapLocalStatus.awaitingUserConfirmation,
  );
}
