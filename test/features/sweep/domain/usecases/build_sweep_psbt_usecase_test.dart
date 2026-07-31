import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/tx_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_quote.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/build_sweep_psbt_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Outpoint;

import '../../../coins/wallet_utxo_fixture.dart';

class _MockBitcoinSendPort extends Mock implements BitcoinSendPort {}

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

const _alice = 'tb1qalice000000000000000000000000000000000';

void main() {
  late _MockBitcoinSendPort sendPort;
  late _MockWalletUtxoRepository utxoRepository;
  late _MockPayjoinSessions payjoin;
  late BuildSweepPsbtUsecase usecase;

  final inputs = <WalletUtxo>[
    walletUtxoFixture(sats: 60000, txId: 'a', vout: 0),
    walletUtxoFixture(sats: 40000, txId: 'b', vout: 1),
  ];
  final fee = NetworkFee.relativeFromSatPerVbyte(2);

  SweepPlan buildPlan() {
    final result = SweepPlan.validate(
      inputs: inputs,
      allocations: [
        SweepAllocation(address: _alice, amountSat: BigInt.from(30000)),
      ],
    );
    return (result as Ok<SweepPlan, SweepFailure>).value;
  }

  setUpAll(() {
    registerFallbackValue(NetworkFee.absolute(0));
    registerFallbackValue(<TxRecipient>[]);
    registerFallbackValue(<WalletUtxo>[]);
  });

  setUp(() {
    sendPort = _MockBitcoinSendPort();
    utxoRepository = _MockWalletUtxoRepository();
    payjoin = _MockPayjoinSessions();
    usecase = BuildSweepPsbtUsecase(
      bitcoinSendPort: sendPort,
      walletUtxoRepository: utxoRepository,
      payjoinSessions: payjoin,
    );
  });

  void stubNothingUnspendable() {
    when(
      () => utxoRepository.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => <Outpoint>[]);
    when(
      () => payjoin.reservedOutpoints(),
    ).thenAnswer((_) async => const Ok<Set<Outpoint>, PayjoinFailure>({}));
  }

  void stubSuccessfulBuild() {
    when(
      () => sendPort.buildSweepPsbt(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        inputs: any(named: 'inputs'),
        networkFee: any(named: 'networkFee'),
      ),
    ).thenAnswer((_) async => 'psbt-base64');
    when(
      () => sendPort.getTxSize(psbt: any(named: 'psbt')),
    ).thenAnswer((_) async => 220);
    when(
      () => sendPort.getTxFeeAmount(psbt: any(named: 'psbt')),
    ).thenAnswer((_) async => 440);
  }

  group('unspendable inputs', () {
    test('refuses when a selected coin is frozen', () async {
      when(
        () => utxoRepository.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => [(txId: 'b', vout: 1)]);
      when(
        () => payjoin.reservedOutpoints(),
      ).thenAnswer((_) async => const Ok<Set<Outpoint>, PayjoinFailure>({}));

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: buildPlan(),
        networkFee: fee,
      );

      final failure = (result as Err<SweepQuote, SweepFailure>).failure;
      expect(failure, isA<SweepUnspendableInputFailure>());
      expect((failure as SweepUnspendableInputFailure).count, 1);
      // The invariant that matters: nothing was built.
      verifyNever(
        () => sendPort.buildSweepPsbt(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          inputs: any(named: 'inputs'),
          networkFee: any(named: 'networkFee'),
        ),
      );
    });

    test('refuses when a selected coin is payjoin-reserved', () async {
      when(
        () => utxoRepository.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => <Outpoint>[]);
      when(() => payjoin.reservedOutpoints()).thenAnswer(
        (_) async =>
            const Ok<Set<Outpoint>, PayjoinFailure>({(txId: 'a', vout: 0)}),
      );

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: buildPlan(),
        networkFee: fee,
      );

      expect(
        (result as Err<SweepQuote, SweepFailure>).failure,
        isA<SweepUnspendableInputFailure>(),
      );
    });

    test('counts every blocked coin, not just the first', () async {
      when(
        () => utxoRepository.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => [(txId: 'a', vout: 0), (txId: 'b', vout: 1)]);
      when(
        () => payjoin.reservedOutpoints(),
      ).thenAnswer((_) async => const Ok<Set<Outpoint>, PayjoinFailure>({}));

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: buildPlan(),
        networkFee: fee,
      );

      final failure =
          (result as Err<SweepQuote, SweepFailure>).failure
              as SweepUnspendableInputFailure;
      expect(failure.count, 2);
    });

    test('a frozen coin outside the selection is irrelevant', () async {
      when(
        () => utxoRepository.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => [(txId: 'other', vout: 7)]);
      when(
        () => payjoin.reservedOutpoints(),
      ).thenAnswer((_) async => const Ok<Set<Outpoint>, PayjoinFailure>({}));
      stubSuccessfulBuild();

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: buildPlan(),
        networkFee: fee,
      );

      expect(result, isA<Ok<SweepQuote, SweepFailure>>());
    });
  });

  group('successful build', () {
    test('reports the fee read off the psbt, not the requested rate', () async {
      stubNothingUnspendable();
      stubSuccessfulBuild();

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: buildPlan(),
        networkFee: fee,
      );

      final quote = (result as Ok<SweepQuote, SweepFailure>).value;
      expect(quote.unsignedPsbt, 'psbt-base64');
      expect(quote.txSize, 220);
      expect(quote.feeSat, BigInt.from(440));
      // 100_000 total − 30_000 pinned − 440 fee.
      expect(quote.changeSat, BigInt.from(69560));
      expect(quote.remainderSat, isNull);
      expect(quote.changeAbsorbedIntoFee, isFalse);
    });

    test('passes exactly the plan inputs down to the port', () async {
      stubNothingUnspendable();
      stubSuccessfulBuild();
      final plan = buildPlan();

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: plan,
        networkFee: fee,
      );
      expect(result, isA<Ok<SweepQuote, SweepFailure>>());

      final captured = verify(
        () => sendPort.buildSweepPsbt(
          walletId: 'wallet-1',
          recipients: captureAny(named: 'recipients'),
          inputs: captureAny(named: 'inputs'),
          networkFee: fee,
        ),
      ).captured;
      expect(captured[0], plan.recipients);
      expect(captured[1], plan.inputs);
    });
  });

  group('failures', () {
    test('reports the exact shortfall from a coin-selection error', () async {
      // The real message BDK produced on a 1188-sat selection. Regression: it
      // used to fall through to the generic catch, so the user saw "oops"
      // instead of how much was missing.
      stubNothingUnspendable();
      when(
        () => sendPort.buildSweepPsbt(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          inputs: any(named: 'inputs'),
          networkFee: any(named: 'networkFee'),
        ),
      ).thenThrow(
        bdk.CoinSelectionCreateTxException(
          'Insufficient funds: 0.00001188 BTC available of '
          '0.00001242 BTC needed',
        ),
      );

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: buildPlan(),
        networkFee: fee,
      );

      final failure =
          (result as Err<SweepQuote, SweepFailure>).failure
              as SweepInsufficientFundsFailure;
      expect(failure.shortfallSat, BigInt.from(54)); // 1242 − 1188
    });

    test('still classifies a coin-selection error it cannot parse', () async {
      stubNothingUnspendable();
      when(
        () => sendPort.buildSweepPsbt(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          inputs: any(named: 'inputs'),
          networkFee: any(named: 'networkFee'),
        ),
      ).thenThrow(
        bdk.CoinSelectionCreateTxException('some future upstream wording'),
      );

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: buildPlan(),
        networkFee: fee,
      );

      final failure =
          (result as Err<SweepQuote, SweepFailure>).failure
              as SweepInsufficientFundsFailure;
      // Classified correctly, just without a figure to show.
      expect(failure.shortfallSat, isNull);
    });

    test('maps a build error to a modeled failure', () async {
      stubNothingUnspendable();
      when(
        () => sendPort.buildSweepPsbt(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          inputs: any(named: 'inputs'),
          networkFee: any(named: 'networkFee'),
        ),
      ).thenThrow(Exception('bdk exploded'));

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: buildPlan(),
        networkFee: fee,
      );

      expect(
        (result as Err<SweepQuote, SweepFailure>).failure,
        isA<SweepBuildFailure>(),
      );
    });

    test('refuses to build when the frozen set cannot be read', () async {
      when(
        () => utxoRepository.getAllFrozenOutpoints(),
      ).thenThrow(Exception('db down'));

      final result = await usecase.execute(
        walletId: 'wallet-1',
        plan: buildPlan(),
        networkFee: fee,
      );

      expect(
        (result as Err<SweepQuote, SweepFailure>).failure,
        isA<SweepBuildFailure>(),
      );
      verifyNever(
        () => sendPort.buildSweepPsbt(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          inputs: any(named: 'inputs'),
          networkFee: any(named: 'networkFee'),
        ),
      );
    });
  });
}
