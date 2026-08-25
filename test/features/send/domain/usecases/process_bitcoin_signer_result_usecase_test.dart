import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/process_bitcoin_signer_result_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _psbt =
    'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9'
    '////AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAU'
    'MzMzMzMzMzMzMzMzMzMzMzMzMzMAAA==';
const _transaction =
    '020000000111111111111111111111111111111111111111111111111111111111'
    '111111110000000000fdffffff01a0860100000000001600142222222222222222'
    '22222222222222222222222200000000';

class _MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class _MockBitcoinSigningPort extends Mock implements BitcoinSigningPort {}

void main() {
  late _MockSignBitcoinTxUsecase signBitcoin;
  late _MockBitcoinSigningPort signingPort;
  late ProcessBitcoinSignerResultUsecase usecase;

  setUp(() {
    signBitcoin = _MockSignBitcoinTxUsecase();
    signingPort = _MockBitcoinSigningPort();
    usecase = ProcessBitcoinSignerResultUsecase(signBitcoin, signingPort);
  });

  test('combines a returned PSBT with the prepared PSBT', () async {
    when(
      () => signBitcoin.execute(
        psbt: 'current',
        walletId: 'wallet',
        externalPsbt: _psbt,
      ),
    ).thenAnswer(
      (_) async =>
          const Ok((signedPsbt: 'combined', txSize: 120, isFinalized: true)),
    );

    final result = await usecase.execute(
      result: _psbt,
      kind: BitcoinSignerResultKind.detect,
      currentPsbt: 'current',
      walletId: 'wallet',
    );

    final processed = (result as Ok).value as ProcessedBitcoinPsbt;
    expect(processed.psbt, 'combined');
    expect(processed.txSize, 120);
  });

  test('verifies a returned raw transaction against the PSBT', () async {
    when(
      () => signingPort.verifyFinalTransaction(
        psbt: 'current',
        transaction: _transaction,
      ),
    ).thenAnswer(
      (_) async => const Ok((transaction: 'verified-transaction', txSize: 100)),
    );

    final result = await usecase.execute(
      result: _transaction,
      kind: BitcoinSignerResultKind.transaction,
      currentPsbt: 'current',
      walletId: 'wallet',
    );

    final processed = (result as Ok).value as ProcessedBitcoinTransaction;
    expect(processed.transaction, 'verified-transaction');
    expect(processed.txSize, 100);
  });

  test('rejects a raw transaction in a PSBT-only flow', () async {
    final result = await usecase.execute(
      result: _transaction,
      kind: BitcoinSignerResultKind.psbt,
      currentPsbt: 'current',
      walletId: 'wallet',
    );

    expect(
      result,
      isA<Err<ProcessedBitcoinSignerResult, BitcoinSigningFailure>>(),
    );
    verifyNever(
      () => signingPort.verifyFinalTransaction(
        psbt: any(named: 'psbt'),
        transaction: any(named: 'transaction'),
      ),
    );
  });
}
