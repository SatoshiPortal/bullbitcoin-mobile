import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart'
    as core;
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCoreDeleteWalletUsecase extends Mock
    implements core.DeleteWalletUsecase {}

class _MockSwapFacade extends Mock implements SwapFacade {}

void main() {
  late _MockCoreDeleteWalletUsecase coreDelete;
  late _MockSwapFacade swapFacade;
  late DeleteWalletUsecase usecase;

  setUp(() {
    coreDelete = _MockCoreDeleteWalletUsecase();
    swapFacade = _MockSwapFacade();
    usecase = DeleteWalletUsecase(coreDelete, swapFacade);
  });

  test('blocks deletion for a creation-unknown source wallet', () async {
    when(swapFacade.getPendingOrders).thenAnswer(
      (_) async => Ok([_record(OrderSwapLocalStatus.creationUnknown)]),
    );

    final result = await usecase.execute(walletId: 'wallet-1');

    expect(
      (result as Err).failure,
      isA<WalletCannotDeleteWithOngoingSwapsFailure>(),
    );
    verifyNever(() => coreDelete.execute(walletId: any(named: 'walletId')));
  });

  test('does not delete when active-order lookup fails', () async {
    when(swapFacade.getPendingOrders).thenAnswer(
      (_) async => const Err(SwapStorageFailure('database unavailable')),
    );

    final result = await usecase.execute(walletId: 'wallet-1');

    final failure = (result as Err).failure as WalletFailure;
    expect(failure, isA<WalletUnexpectedFailure>());
    // The swap feature's reason must not survive into the wallet family.
    expect(failure.logMessage, isNot(contains('database unavailable')));
    verifyNever(() => coreDelete.execute(walletId: any(named: 'walletId')));
  });

  test('delegates deletion when no active order uses the wallet', () async {
    when(swapFacade.getPendingOrders).thenAnswer((_) async => const Ok([]));
    when(
      () => coreDelete.execute(walletId: 'wallet-1'),
    ).thenAnswer((_) async => const Ok<void, WalletFailure>(null));

    final result = await usecase.execute(walletId: 'wallet-1');

    expect(result, isA<Ok<void, WalletFailure>>());

    verify(() => coreDelete.execute(walletId: 'wallet-1')).called(1);
  });
}

OrderSwapRecord _record(OrderSwapLocalStatus status) => OrderSwapRecord(
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
  createdAt: DateTime.utc(2026),
  localStatus: status,
);
