import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/wallet_spend_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_send_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_send_signed_tx_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show BitcoinSpendStatus;
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

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

  SendSpendTestDouble({
    required this.read,
    required this.prepare,
    required this.fees,
    required this.sign,
    required this.broadcast,
    required this.preview,
    required this.presets,
    required this.verify,
  });

  List<WalletUtxo> _coins(Set<Outpoint>? inputs) => [
    for (final coin in read().selectedUtxos)
      if (inputs?.contains(coin.outpoint) ?? false) coin,
  ];

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
