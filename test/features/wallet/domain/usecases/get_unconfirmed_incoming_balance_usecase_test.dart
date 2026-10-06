import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

/// The "+N sats incoming" figure on the home balance.
///
/// [BoltzSwapRepository] is a shared core repository that still throws, so
/// this use case is the wallet feature's boundary for it (#1895).
///
/// `Swap` is sealed, so these are real entities rather than mocks — which is
/// the better test anyway: it exercises the real `receieveAmount` arithmetic.
/// Both wallets in the fixture: the swap sends from w1 and receives into w2.
/// Listing both keeps these tests independent of whether the use-case ever
/// filters by walletIds, which it does not today (a follow-up question).
const _bothWallets = ['w1', 'w2'];

/// The value an [Ok] carries; an [Err] fails the test.
int _valueOf(Result<int, WalletFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

void main() {
  late _MockBoltzSwapRepository swapRepository;
  late GetUnconfirmedIncomingBalanceUsecase usecase;

  /// An internal chain swap (both legs ours), the shape that counts toward the
  /// incoming figure. `receieveAmount` is `paymentAmount - claimFee`.
  Swap internalChainSwap({
    required SwapStatus status,
    required int paymentAmount,
    int? claimFee = 0,
    String? receiveWalletId = 'w2',
  }) {
    return Swap.chain(
      id: 'swap-$status-$paymentAmount',
      keyIndex: 0,
      type: SwapType.bitcoinToLiquid,
      status: status,
      environment: Environment.mainnet,
      creationTime: DateTime(2026),
      sendWalletId: 'w1',
      paymentAddress: 'bc1qexampleaddress',
      paymentAmount: paymentAmount,
      receiveWalletId: receiveWalletId,
      fees: claimFee == null ? null : SwapFees(claimFee: claimFee),
    );
  }

  setUp(() {
    swapRepository = _MockBoltzSwapRepository();
    usecase = GetUnconfirmedIncomingBalanceUsecase(
      boltzSwapRepository: swapRepository,
    );
  });

  test('sums paid, claimable and refundable incoming swaps', () async {
    when(() => swapRepository.getAllSwaps()).thenAnswer(
      (_) async => [
        internalChainSwap(status: SwapStatus.paid, paymentAmount: 1000),
        internalChainSwap(status: SwapStatus.claimable, paymentAmount: 250),
        internalChainSwap(status: SwapStatus.refundable, paymentAmount: 25),
      ],
    );

    expect(_valueOf(await usecase.execute(walletIds: _bothWallets)), 1275);
  });

  test('subtracts the swap fees from the incoming figure', () async {
    when(() => swapRepository.getAllSwaps()).thenAnswer(
      (_) async => [
        internalChainSwap(
          status: SwapStatus.paid,
          paymentAmount: 1000,
          claimFee: 150,
        ),
      ],
    );

    expect(_valueOf(await usecase.execute(walletIds: _bothWallets)), 850);
  });

  test('ignores a status that is not incoming yet', () async {
    when(() => swapRepository.getAllSwaps()).thenAnswer(
      (_) async => [
        internalChainSwap(status: SwapStatus.completed, paymentAmount: 9999),
        internalChainSwap(status: SwapStatus.pending, paymentAmount: 8888),
        internalChainSwap(status: SwapStatus.paid, paymentAmount: 1000),
      ],
    );

    expect(_valueOf(await usecase.execute(walletIds: _bothWallets)), 1000);
  });

  test('ignores an external chain swap — it is not coming to us', () async {
    when(() => swapRepository.getAllSwaps()).thenAnswer(
      (_) async => [
        internalChainSwap(
          status: SwapStatus.paid,
          paymentAmount: 5000,
          receiveWalletId: null,
        ),
      ],
    );

    expect(_valueOf(await usecase.execute(walletIds: _bothWallets)), 0);
  });

  test('a swap with no known amount counts as zero, not null', () async {
    when(() => swapRepository.getAllSwaps()).thenAnswer(
      (_) async => [
        internalChainSwap(
          status: SwapStatus.paid,
          paymentAmount: 1000,
          claimFee: null,
        ),
      ],
    );

    expect(_valueOf(await usecase.execute(walletIds: _bothWallets)), 0);
  });

  test('no swaps is zero, not a failure', () async {
    when(() => swapRepository.getAllSwaps()).thenAnswer((_) async => []);

    expect(_valueOf(await usecase.execute(walletIds: _bothWallets)), 0);
  });

  test('sanitizes a throwing swap read', () async {
    when(
      () => swapRepository.getAllSwaps(),
    ).thenThrow(StateError('boltz api 502 at https://api.boltz.exchange/v2'));

    final result = await usecase.execute(walletIds: _bothWallets);

    final failure = switch (result) {
      Ok() => fail('expected an Err, got Ok'),
      Err(:final failure) => failure,
    };
    expect(failure, isA<WalletUnexpectedFailure>());
    // A swap-backend URL is not something the balance widget should ever be
    // in a position to render.
    expect(failure.logMessage, isNot(contains('api.boltz.exchange')));
  });
}
