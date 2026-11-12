import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/liquid_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _LiquidSendPort extends Mock implements LiquidSendPort {}

void main() {
  late _LiquidSendPort port;
  late PrepareLiquidSendUsecase usecase;
  const selection = {(txId: 'selected', vout: 0)};

  setUpAll(() => registerFallbackValue(const RelativeFee(25)));
  setUp(() {
    port = _LiquidSendPort();
    usecase = PrepareLiquidSendUsecase(liquidWalletRepository: port);
  });

  void stub(Result<String, WalletFailure> result) {
    when(
      () => port.buildPset(
        walletId: 'wallet',
        address: 'recipient',
        feeRate: any(named: 'feeRate'),
        amountSat: any(named: 'amountSat'),
        drain: any(named: 'drain'),
        selectedInputs: any(named: 'selectedInputs'),
      ),
    ).thenAnswer((_) async => result);
  }

  Future<Result<String, SendFailure>> run({
    bool selected = false,
    bool drain = false,
    int? amount = 1000,
  }) => usecase.execute(
    walletId: 'wallet',
    address: 'recipient',
    feeRate: const RelativeFee(25),
    amountSat: amount,
    drain: drain,
    selectedInputs: selected ? selection : null,
  );

  test('returns the PSET and forwards the exact drain selection', () async {
    stub(const Ok('pset'));
    expect(
      (await run(selected: true, drain: true) as Ok<String, SendFailure>).value,
      'pset',
    );
    verify(
      () => port.buildPset(
        walletId: 'wallet',
        address: 'recipient',
        feeRate: const RelativeFee(25),
        drain: true,
        selectedInputs: selection,
      ),
    ).called(1);
  });

  test('rejects missing fixed amount before reaching the port', () async {
    expect(
      (await run(amount: null) as Err<String, SendFailure>).failure,
      isA<SendTransactionBuildFailure>(),
    );
    verifyZeroInteractions(port);
  });

  for (final (walletFailure, automatic, selected)
      in <(WalletFailure, Matcher, Matcher)>[
        (
          const WalletSelectedInputsUnavailableFailure(),
          isA<SendSelectedCoinsUnavailableFailure>(),
          isA<SendSelectedCoinsUnavailableFailure>(),
        ),
        (
          const WalletNoSpendableInputsFailure(),
          isA<SendInsufficientBalanceFailure>(),
          isA<SendSelectedCoinsUnavailableFailure>(),
        ),
        (
          const WalletInsufficientFundsFailure(),
          isA<SendInsufficientFundsForFeesFailure>(),
          isA<SendSelectedCoinsInsufficientFailure>(),
        ),
        (
          const WalletConsolidationRequiredFailure(),
          isA<SendConsolidationRequiredFailure>(),
          isA<SendConsolidationRequiredFailure>(),
        ),
        (
          const WalletTransactionBuildFailure(),
          isA<SendTransactionBuildFailure>(),
          isA<SendTransactionBuildFailure>(),
        ),
      ]) {
    test(
      'maps ${walletFailure.runtimeType} for automatic and exact selection',
      () async {
        stub(Err(walletFailure));
        expect((await run() as Err<String, SendFailure>).failure, automatic);
        expect(
          (await run(selected: true) as Err<String, SendFailure>).failure,
          selected,
        );
      },
    );
  }
}
