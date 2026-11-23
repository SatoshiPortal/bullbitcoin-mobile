import 'legacy_spend_fixture.dart';
export 'legacy_spend_fixture.dart';

import 'package:spend/legacy_exceptions.dart';
import 'package:coins/coins.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:sync/sync.dart' show BitcoinSpendStatus;
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

typedef PreparedBitcoinSend = ({
  String unsignedPsbt,
  int txSize,
  bool isToSelf,
  List<Sats> recipientAmountsSat,
});

abstract interface class PrepareSendBitcoinTransactionUsecase {
  Future<Result<PreparedBitcoinSend, SendFailure>> execute({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    List<WalletUtxo>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
    bool hasFrozenInputs = false,
  });
}

abstract interface class CalculateBitcoinAbsoluteFeesUsecase {
  Future<int> execute({required String psbt});
}

abstract interface class SignBitcoinTxUsecase {
  Future<({String signedPsbt, int txSize})> execute({
    required String psbt,
    required String walletId,
  });
}

abstract interface class BroadcastBitcoinTransactionUsecase {
  Future<String> execute(
    String transaction, {
    required bool isPsbt,
    required Network network,
    String? walletId,
  });
}

abstract interface class PreviewBitcoinFeeUsecase {
  Future<BitcoinFeePreviewSlot> execute({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    required bool replaceByFee,
    required List<WalletUtxo> selectedInputs,
    bool selectedOnly = false,
  });
}

abstract interface class PreviewBitcoinFeePresetsUsecase {
  Future<Map<FeeSelection, BitcoinFeePreviewSlot>> execute({
    required FeeOptions presets,
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required bool replaceByFee,
    required List<WalletUtxo> selectedInputs,
    bool selectedOnly = false,
  });
}

abstract interface class VerifySendSignedTxUsecase {
  Future<Result<void, SendFailure>> execute({
    required String unsignedPsbt,
    required String signedTransaction,
  });
}

abstract interface class PrepareLiquidSendUsecase {
  Future<Result<String, SendFailure>> execute({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    Set<Outpoint>? selectedInputs,
    bool hasFrozenInputs = false,
  });
}

abstract interface class SignLiquidTxUsecase {
  Future<String> execute({required String pset, required String walletId});
}

abstract interface class CalculateLiquidAbsoluteFeesUsecase {
  Future<int> execute({required String pset});
}

abstract interface class CalculateLiquidPsetSizeUsecase {
  Future<Result<int, SendFailure>> execute({required String pset});
}

abstract interface class BroadcastLiquidTransactionUsecase {
  Future<String> execute(
    String signedPset, {
    Object? network,
    bool? isTestnet,
    String? walletId,
  });
}

/// Runs existing Send orchestration scenarios against a Spend double while
/// retaining their independently stubbed build, sign and relay checkpoints.
final class SendSpendTestDouble extends FakeSpend {
  final SendState Function() read;
  final PrepareSendBitcoinTransactionUsecase prepare;
  final CalculateBitcoinAbsoluteFeesUsecase fees;
  final SignBitcoinTxUsecase sign;
  final BroadcastBitcoinTransactionUsecase broadcast;
  final PreviewBitcoinFeeUsecase preview;
  final PreviewBitcoinFeePresetsUsecase presets;
  final VerifySendSignedTxUsecase verify;
  final PrepareLiquidSendUsecase? prepareLiquidUsecase;
  final SignLiquidTxUsecase? signLiquidUsecase;
  final BroadcastLiquidTransactionUsecase? broadcastLiquidUsecase;
  final CalculateLiquidAbsoluteFeesUsecase? liquidFeesUsecase;
  final CalculateLiquidPsetSizeUsecase? liquidSizeUsecase;

  SendSpendTestDouble({
    required this.read,
    required this.prepare,
    required this.fees,
    required this.sign,
    required this.broadcast,
    required this.preview,
    required this.presets,
    required this.verify,
    this.prepareLiquidUsecase,
    this.signLiquidUsecase,
    this.broadcastLiquidUsecase,
    this.liquidFeesUsecase,
    this.liquidSizeUsecase,
  });

  List<WalletUtxo> _coins(Set<Outpoint>? inputs) => [
    for (final coin in read().selectedUtxos)
      if (inputs?.contains(coin.outpoint) ?? false) coin,
  ];

  @override
  Future<Result<PreparedLiquidSpend, SpendFailure>> prepareLiquid({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    Set<Outpoint>? selectedInputs,
  }) async {
    final prepareLiquid = prepareLiquidUsecase;
    if (prepareLiquid == null) {
      throw StateError('Unexpected Liquid preparation');
    }
    final preparation = await prepareLiquid.execute(
      walletId: walletId,
      address: address,
      feeRate: feeRate,
      amountSat: amountSat,
      drain: drain,
      selectedInputs: selectedInputs,
      hasFrozenInputs: read().frozenBalanceSat > 0,
    );
    switch (preparation) {
      case Err(:final failure):
        return Err(switch (failure) {
          SendSelectedCoinsUnavailableFailure() =>
            const SpendSelectedInputsUnavailableFailure(),
          SendSelectedCoinsInsufficientFailure() ||
          SendInsufficientBalanceFailure() ||
          SendInsufficientFundsForFeesFailure() =>
            const SpendInsufficientFundsFailure(),
          SendConsolidationRequiredFailure() =>
            const SpendConsolidationRequiredFailure(),
          SendAddressNetworkMismatchFailure() =>
            const SpendNetworkMismatchFailure(),
          _ => const SpendBuildRefusedFailure(),
        });
      case Ok(:final value):
        final fees = liquidFeesUsecase;
        if (fees == null) throw StateError('Unexpected Liquid fee read');
        final fee = await fees.execute(pset: value);
        var size = 1;
        final sizeReader = liquidSizeUsecase;
        if (feeRate.satPerKwu == 25 && sizeReader != null) {
          final result = await sizeReader.execute(pset: value);
          if (result case Ok(value: final int vsize)) size = vsize;
        }
        return Ok(
          SpendFixtures.preparedLiquid(
            unsignedPset: value,
            fee: Sats.fromInt(fee),
            amountSent: Sats.fromInt(amountSat ?? 0),
            discountedVsize: size,
          ),
        );
    }
  }

  @override
  Future<Result<SignedLiquidSpend, SpendFailure>> signLiquid({
    required PreparedLiquidSpend prepared,
  }) async {
    final wallet = read().selectedWallet;
    if (wallet == null) return const Err(SpendInvalidRequestFailure());
    final signLiquid = signLiquidUsecase;
    if (signLiquid == null) throw StateError('Unexpected Liquid signing');
    final signed = await signLiquid.execute(
      pset: prepared.unsignedPset,
      walletId: wallet.id,
    );
    return Ok(SpendFixtures.signedLiquid(signed));
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastLiquid(
    SignedLiquidSpend signed,
  ) async {
    final wallet = read().selectedWallet;
    if (wallet == null) return const Err(SpendInvalidRequestFailure());
    final broadcastLiquid = broadcastLiquidUsecase;
    if (broadcastLiquid == null) {
      throw StateError('Unexpected Liquid broadcast');
    }
    final txid = await broadcastLiquid.execute(
      signed.signedPset,
      network: wallet.network,
    );
    return Ok((txid: txid, guarded: false, durable: false));
  }

  @override
  Future<Result<PreparedBitcoinSpend, SpendFailure>> prepareBitcoin({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    Set<Outpoint>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  }) async {
    try {
      final result = await prepare.execute(
        walletId: walletId,
        recipients: recipients,
        networkFee: networkFee,
        selectedInputs: _coins(selectedInputs),
        selectedOnly: selectedOnly,
        replaceByFee: replaceByFee,
        hasFrozenInputs: read().frozenBalanceSat > 0,
      );
      return switch (result) {
        Ok(:final value) => Ok(
          SpendFixtures.preparedBitcoin(
            unsignedPsbt: value.unsignedPsbt,
            fee: Sats.fromInt(await fees.execute(psbt: value.unsignedPsbt)),
            txSize: value.txSize,
            isToSelf: value.isToSelf,
            recipientAmountsSat: value.recipientAmountsSat,
          ),
        ),
        Err(:final failure) => Err(switch (failure) {
          SendSelectedCoinsUnavailableFailure() =>
            const SpendSelectedInputsUnavailableFailure(),
          SendSelectedCoinsInsufficientFailure() ||
          SendInsufficientBalanceFailure() ||
          SendInsufficientFundsForFeesFailure() =>
            const SpendInsufficientFundsFailure(),
          SendSpendBlockedFailure(:final busy) => SpendUnavailableFailure(
            busy: busy,
          ),
          SendAddressNetworkMismatchFailure() =>
            const SpendNetworkMismatchFailure(),
          _ => const SpendBuildRefusedFailure(),
        }),
      };
    } on WalletSpendBlockedException catch (error) {
      return Err(
        SpendUnavailableFailure(busy: error.status == BitcoinSpendStatus.busy),
      );
    } on InsufficientFundsException {
      return const Err(SpendInsufficientFundsFailure());
    } on NoSpendableUtxoException {
      return selectedInputs == null || selectedInputs.isEmpty
          ? const Err(SpendNoSpendableInputsFailure())
          : const Err(SpendSelectedInputsUnavailableFailure());
    }
  }

  BitcoinSpendPreview? _project(BitcoinFeePreviewSlot slot) {
    final psbt = slot.unsignedPsbt;
    final fee = slot.feeSat;
    final size = slot.txSize;
    if (psbt == null || fee == null || size == null) return null;
    return (
      prepared: SpendFixtures.preparedBitcoin(
        unsignedPsbt: psbt,
        fee: Sats.fromInt(fee),
        txSize: size,
        isToSelf: slot.isToSelf ?? false,
        recipientAmountsSat: slot.recipientAmountsSat
            .map(Sats.fromInt)
            .toList(),
      ),
      fee: Sats.fromInt(fee),
    );
  }

  @override
  Future<Result<BitcoinSpendPreview?, SpendFailure>> previewBitcoinFee({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    required bool replaceByFee,
    required Set<Outpoint> selectedInputs,
    bool selectedOnly = false,
  }) async => Ok(
    _project(
      await preview.execute(
        walletId: walletId,
        recipients: recipients,
        networkFee: networkFee,
        replaceByFee: replaceByFee,
        selectedInputs: _coins(selectedInputs),
        selectedOnly: selectedOnly,
      ),
    ),
  );

  @override
  Future<Result<Map<FeeSelection, BitcoinSpendPreview?>, SpendFailure>>
  previewBitcoinFeePresets({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required FeeOptions presets,
    required bool replaceByFee,
    required Set<Outpoint> selectedInputs,
    bool selectedOnly = false,
  }) async => Ok(
    (await this.presets.execute(
      walletId: walletId,
      recipients: recipients,
      presets: presets,
      replaceByFee: replaceByFee,
      selectedInputs: _coins(selectedInputs),
      selectedOnly: selectedOnly,
    )).map((key, slot) => MapEntry(key, _project(slot))),
  );

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async {
    final wallet = read().selectedWallet;
    if (wallet == null) return const Err(SpendInvalidRequestFailure());
    final result = await sign.execute(
      psbt: prepared.unsignedPsbt,
      walletId: wallet.id,
    );
    return Ok(
      SpendFixtures.signedBitcoin(result.signedPsbt, txSize: result.txSize),
    );
  }

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> verifySignedBitcoin({
    required PreparedBitcoinSpend prepared,
    required String signedTransaction,
    required bool isPsbt,
  }) async =>
      (await verify.execute(
            unsignedPsbt: prepared.unsignedPsbt,
            signedTransaction: signedTransaction,
          ))
          .map((_) => SpendFixtures.signedBitcoin(signedTransaction))
          .mapErr((_) => const SpendSignedTransactionMismatchFailure());

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastBitcoin(
    SignedBitcoinSpend signed,
  ) async {
    final state = read();
    final wallet = state.selectedWallet;
    if (wallet == null) return const Err(SpendInvalidRequestFailure());
    try {
      final txid = await broadcast.execute(
        signed.signedTransaction,
        network: wallet.network,
        isPsbt: state.signedBitcoinTx == null,
        walletId: wallet.id,
      );
      return Ok((txid: txid, guarded: true, durable: true));
    } on WalletSpendBlockedException catch (error) {
      return Err(
        SpendUnavailableFailure(busy: error.status == BitcoinSpendStatus.busy),
      );
    } on BroadcastTransactionException catch (error) {
      return Err(switch (BroadcastFailureCategory.of(error)) {
        BroadcastFailureCategory.rejected =>
          const SpendBroadcastRejectedFailure(
            SpendBroadcastRejection.nodeRejected,
          ),
        BroadcastFailureCategory.authorization =>
          const SpendDeveloperAuthorizationFailure(),
        BroadcastFailureCategory.alreadyInChain =>
          const SpendAlreadyInChainFailure(),
        _ => const SpendBroadcastOutcomeUnknownFailure(),
      });
    }
  }
}
