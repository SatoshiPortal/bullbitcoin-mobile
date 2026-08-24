import 'package:bb_mobile/core/utils/bitcoin_signer_result.dart' as core;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_bitcoin_signing_plan_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:meta/meta.dart';

enum BitcoinSignerResultKind { detect, psbt, transaction }

sealed class ProcessedBitcoinSignerResult {
  const ProcessedBitcoinSignerResult();
}

final class ProcessedBitcoinTransaction extends ProcessedBitcoinSignerResult {
  final String transaction;
  final int txSize;

  const ProcessedBitcoinTransaction({
    required this.transaction,
    required this.txSize,
  });
}

final class ProcessedBitcoinPsbt extends ProcessedBitcoinSignerResult {
  final String psbt;
  final bool isFinalized;
  final int txSize;
  final int absoluteFeesSat;
  final BitcoinSigningPlan signingPlan;

  const ProcessedBitcoinPsbt({
    required this.psbt,
    required this.isFinalized,
    required this.txSize,
    required this.absoluteFeesSat,
    required this.signingPlan,
  });
}

class ProcessBitcoinSignerResultUsecase {
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final GetBitcoinSigningPlanUsecase _getBitcoinSigningPlanUsecase;
  final BitcoinSigningPort _bitcoinSigningPort;

  const ProcessBitcoinSignerResultUsecase(
    this._signBitcoinTxUsecase,
    this._getBitcoinSigningPlanUsecase,
    this._bitcoinSigningPort,
  );

  @useResult
  Future<Result<ProcessedBitcoinSignerResult, BitcoinSigningFailure>> execute({
    required String result,
    required BitcoinSignerResultKind kind,
    required String currentPsbt,
    required Wallet? wallet,
    required BitcoinPolicySelection selection,
    Set<String> satisfiedPreimageKeys = const {},
  }) async {
    final core.ParsedBitcoinSignerResult parsed;
    try {
      parsed = core.parseBitcoinSignerResult(result);
    } on FormatException {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.invalidPsbt),
      );
    }
    final expectedFormat = switch (kind) {
      BitcoinSignerResultKind.detect => null,
      BitcoinSignerResultKind.psbt => core.BitcoinSignerResultFormat.psbt,
      BitcoinSignerResultKind.transaction =>
        core.BitcoinSignerResultFormat.transaction,
    };
    if (expectedFormat != null && parsed.format != expectedFormat) {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.invalidPsbt),
      );
    }
    return switch (parsed.format) {
      core.BitcoinSignerResultFormat.psbt =>
        wallet == null
            ? const Err(
                BitcoinSigningFailure(BitcoinSigningFailureKind.unexpected),
              )
            : _processPsbt(
                psbt: parsed.value,
                currentPsbt: currentPsbt,
                wallet: wallet,
                selection: selection,
                satisfiedPreimageKeys: satisfiedPreimageKeys,
              ),
      core.BitcoinSignerResultFormat.transaction => _processTransaction(
        transaction: parsed.value,
        currentPsbt: currentPsbt,
      ),
    };
  }

  Future<Result<ProcessedBitcoinTransaction, BitcoinSigningFailure>>
  _processTransaction({
    required String transaction,
    required String currentPsbt,
  }) async {
    final verifiedResult = await _bitcoinSigningPort.verifyFinalTransaction(
      psbt: currentPsbt,
      transaction: transaction,
    );
    return switch (verifiedResult) {
      Ok(:final value) => Ok(
        ProcessedBitcoinTransaction(
          transaction: value.transaction,
          txSize: value.txSize,
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<ProcessedBitcoinPsbt, BitcoinSigningFailure>> _processPsbt({
    required String psbt,
    required String currentPsbt,
    required Wallet wallet,
    required BitcoinPolicySelection selection,
    required Set<String> satisfiedPreimageKeys,
  }) async {
    final signingResultValue = await _signBitcoinTxUsecase.execute(
      psbt: currentPsbt,
      externalPsbt: psbt,
      walletId: wallet.id,
      requireFinalized: false,
      tryFinalize: false,
    );
    final SignedBitcoinTransaction signingResult;
    switch (signingResultValue) {
      case Ok(:final value):
        signingResult = value;
      case Err(:final failure):
        return Err(failure);
    }
    final planResult = await _getBitcoinSigningPlanUsecase.execute(
      wallet: wallet,
      psbt: signingResult.signedPsbt,
      selection: selection,
      satisfiedPreimageKeys: satisfiedPreimageKeys,
    );
    final BitcoinSigningPlanDetails details;
    switch (planResult) {
      case Ok(:final value):
        details = value;
      case Err(:final failure):
        return Err(failure);
    }
    final review = details.review;
    if (review == null) {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unexpected),
      );
    }
    final signingPlan = details.plan;
    var finalized = (psbt: signingResult.signedPsbt, isFinalized: false);
    if (signingPlan.isSatisfied) {
      switch (await _bitcoinSigningPort.finalizePsbt(
        signingResult.signedPsbt,
      )) {
        case Ok(:final value):
          finalized = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (!finalized.isFinalized) {
        return const Err(
          BitcoinSigningFailure(BitcoinSigningFailureKind.incomplete),
        );
      }
    }
    return Ok(
      ProcessedBitcoinPsbt(
        psbt: finalized.psbt,
        isFinalized: finalized.isFinalized,
        txSize: signingResult.txSize,
        absoluteFeesSat: review.feeSat.toInt(),
        signingPlan: signingPlan,
      ),
    );
  }
}
