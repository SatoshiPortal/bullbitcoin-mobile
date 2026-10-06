import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

/// A thin forwarder, tested for exactly that: it must not "helpfully" collapse
/// a failure into a bool, because the bloc decides what an unknown sync state
/// looks like on screen.
void main() {
  late _MockWalletRepository walletRepository;
  late CheckWalletSyncingUsecase usecase;

  setUp(() {
    walletRepository = _MockWalletRepository();
    usecase = CheckWalletSyncingUsecase(walletRepository: walletRepository);
  });

  test('forwards the syncing state', () {
    when(
      () => walletRepository.isWalletSyncing(walletId: any(named: 'walletId')),
    ).thenReturn(const Ok(true));

    expect((usecase.execute(walletId: 'w1') as Ok).value, isTrue);
  });

  test('passes the wallet id through unchanged', () {
    when(
      () => walletRepository.isWalletSyncing(walletId: any(named: 'walletId')),
    ).thenReturn(const Ok(false));

    // The result is asserted too because `execute` is `@useResult` — the
    // annotation is doing its job here and discarding it is a warning.
    expect(usecase.execute(walletId: 'w1'), isA<Ok<bool, WalletFailure>>());

    verify(() => walletRepository.isWalletSyncing(walletId: 'w1')).called(1);
  });

  test('forwards a failure instead of reporting "not syncing"', () {
    // `Err` and `Ok(false)` are different facts: one is "we know it is idle",
    // the other is "we could not tell". Flattening them would make a broken
    // wallet look permanently idle.
    when(
      () => walletRepository.isWalletSyncing(walletId: any(named: 'walletId')),
    ).thenReturn(const Err(WalletUnexpectedFailure('isWalletSyncing failed')));

    final result = usecase.execute();

    expect(result, isA<Err<bool, WalletFailure>>());
    expect((result as Err).failure, isA<WalletUnexpectedFailure>());
  });
}
