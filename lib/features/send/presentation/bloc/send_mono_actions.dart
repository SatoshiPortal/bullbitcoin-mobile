part of 'send_cubit.dart';

/// Opaque, uncommitted drain preview. Its identity belongs to one payment state.
final class SendMonoMaxPreview {
  const SendMonoMaxPreview._(this._snapshot, this._epoch, this._slot);
  final SendState _snapshot;
  final int _epoch;
  final BitcoinFeePreviewSlot _slot;
  int get recipientSat => _slot.recipientAmountsSat.single;
  int get feeSat => _slot.feeSat ?? 0;
  int get availableSat => recipientSat + feeSat;
  bool get selectedCoins => _snapshot.usesSelectedInputsOnly;
  bool get protectedCoinsRemain =>
      availableSat <
      (_snapshot.selectedWallet?.balanceSat?.toInt() ?? availableSat);
}

extension SendMonoActions on SendCubit {
  Future<SendMonoMaxPreview?> previewMonoMax() async {
    final wallet = state.selectedWallet;
    final fee = state.selectedFee;
    if (wallet == null ||
        wallet.isLiquid ||
        fee == null ||
        !state.usesRecipientList ||
        state.hasMultipleRecipients ||
        state.paymentRequestAddress.isEmpty ||
        state.hasFixedRequestAmount) {
      return null;
    }
    _recipientPreviewTimer?.cancel();
    final epoch = ++_bitcoinPreviewEpoch;
    final snapshot = state;
    final slot = await _previewBitcoinFeeUsecase.execute(
      walletId: wallet.id,
      recipients: [
        BitcoinTransactionRecipient.remainder(
          address: state.paymentRequestAddress,
        ),
      ],
      networkFee: fee,
      replaceByFee: state.replaceByFee,
      selectedInputs: state.selectedUtxos,
      selectedOnly: state.usesSelectedInputsOnly,
    );
    if (isClosed ||
        state != snapshot ||
        epoch != _bitcoinPreviewEpoch ||
        !slot.isCacheReady ||
        slot.feeSat == null ||
        (slot.feeSat ?? -1) < 0 ||
        slot.recipientAmountsSat.length != 1 ||
        slot.recipientAmountsSat.single <= 0) {
      return null;
    }
    return SendMonoMaxPreview._(snapshot, epoch, slot);
  }

  Future<bool> acceptMonoMax(SendMonoMaxPreview preview) async {
    if (isClosed ||
        state != preview._snapshot ||
        _bitcoinPreviewEpoch != preview._epoch) {
      return false;
    }
    final applying = amountChanged(isMax: true);
    final applied = state;
    await applying;
    if (isClosed || state != applied || !state.isMaxSend) return false;
    _recipientPreviewTimer?.cancel();
    _bitcoinPreviewEpoch++;
    final slot = preview._slot;
    _applyMonoState(
      state.copyWith(
        amount: _maxAmountText(preview.recipientSat),
        recipientAmountsSat: slot.recipientAmountsSat,
        bitcoinAbsoluteFeesSat: slot.feeSat,
        bitcoinTxSize: slot.txSize,
        isToSelf: slot.isToSelf,
        feePreviewCache: state.feePreviewCache.withSlot(
          state.selectedFeeOption,
          slot,
        ),
      ),
    );
    return true;
  }
}
