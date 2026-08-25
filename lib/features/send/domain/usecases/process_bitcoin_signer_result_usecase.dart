import 'package:bb_mobile/core/utils/bitcoin_signer_result.dart' as core;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:meta/meta.dart';

enum BitcoinSignerResultKind { detect, psbt, transaction }

sealed class ProcessedBitcoinSignerResult {
  const ProcessedBitcoinSignerResult();
}

final class ProcessedBitcoinPsbt extends ProcessedBitcoinSignerResult {
  final String psbt;
  final int txSize;

  const ProcessedBitcoinPsbt({required this.psbt, required this.txSize});
}

final class ProcessedBitcoinTransaction extends ProcessedBitcoinSignerResult {
  final String transaction;
  final int txSize;

  const ProcessedBitcoinTransaction({
    required this.transaction,
    required this.txSize,
  });
}

class ProcessBitcoinSignerResultUsecase {
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final BitcoinSigningPort _bitcoinSigningPort;

  const ProcessBitcoinSignerResultUsecase(
    this._signBitcoinTxUsecase,
    this._bitcoinSigningPort,
  );

  @useResult
  Future<Result<ProcessedBitcoinSignerResult, BitcoinSigningFailure>> execute({
    required String result,
    required BitcoinSignerResultKind kind,
    required String currentPsbt,
    required String walletId,
  }) async {
    final core.ParsedBitcoinSignerResult parsed;
    try {
      parsed = core.parseBitcoinSignerResult(result);
      if (kind == BitcoinSignerResultKind.psbt &&
          parsed.format != core.BitcoinSignerResultFormat.psbt) {
        throw const FormatException('Expected a PSBT');
      }
      if (kind == BitcoinSignerResultKind.transaction &&
          parsed.format != core.BitcoinSignerResultFormat.transaction) {
        throw const FormatException('Expected a transaction');
      }
    } on FormatException {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.invalidPsbt),
      );
    }

    return switch (parsed.format) {
      core.BitcoinSignerResultFormat.psbt => _processPsbt(
        psbt: parsed.value,
        currentPsbt: currentPsbt,
        walletId: walletId,
      ),
      core.BitcoinSignerResultFormat.transaction => _processTransaction(
        transaction: parsed.value,
        currentPsbt: currentPsbt,
      ),
    };
  }

  Future<Result<ProcessedBitcoinPsbt, BitcoinSigningFailure>> _processPsbt({
    required String psbt,
    required String currentPsbt,
    required String walletId,
  }) async {
    final result = await _signBitcoinTxUsecase.execute(
      psbt: currentPsbt,
      externalPsbt: psbt,
      walletId: walletId,
    );
    return switch (result) {
      Ok(:final value) => Ok(
        ProcessedBitcoinPsbt(psbt: value.signedPsbt, txSize: value.txSize),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<ProcessedBitcoinTransaction, BitcoinSigningFailure>>
  _processTransaction({
    required String transaction,
    required String currentPsbt,
  }) async {
    final result = await _bitcoinSigningPort.verifyFinalTransaction(
      psbt: currentPsbt,
      transaction: transaction,
    );
    return switch (result) {
      Ok(:final value) => Ok(
        ProcessedBitcoinTransaction(
          transaction: value.transaction,
          txSize: value.txSize,
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
