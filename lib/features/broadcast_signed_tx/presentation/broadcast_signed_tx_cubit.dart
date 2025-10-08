import 'dart:convert';

import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/errors.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:url_launcher/url_launcher.dart';

class BroadcastSignedTxCubit extends Cubit<BroadcastSignedTxState> {
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;

  BroadcastSignedTxCubit({
    required BroadcastBitcoinTransactionUsecase
    broadcastBitcoinTransactionUsecase,
    String? unsignedPsbt,
  }) : _broadcastBitcoinTransactionUsecase = broadcastBitcoinTransactionUsecase,
       super(BroadcastSignedTxState(bbqr: Bbqr(), unsignedPsbt: unsignedPsbt));

  Future<void> onQrScanned(String payload) async {
    try {
      emit(state.copyWith(error: null));
      if (payload.startsWith('cHN')) {
        // Jade returns a non-finalized PSBT, but BDK doesn't finalize transactions it did not sign itself
        // So here we have to finalize the PSBT with bitcoin_base before we broadcast it
        final psbt = Psbt.fromBase64(payload);
        final builder = PsbtBuilder.fromPsbt(psbt);
        String finalTx;
        try {
          finalTx = builder.finalizeAll().toHex();
        } catch (e) {
          if (state.unsignedPsbt == null) {
            rethrow;
          }

          // Seedsigner doesn't return the original input data, so here we try to add inputs data from the unsigned tx

          final psbt = await bdk.PartiallySignedTransaction.fromString(
            state.unsignedPsbt!,
          );
          final signedPsbt = await bdk.PartiallySignedTransaction.fromString(
            payload,
          );

          final tx = psbt.combine(signedPsbt);

          final finalPsbt = Psbt.deserialize(tx.serialize());

          final builder = PsbtBuilder.fromPsbt(finalPsbt);
          finalTx = builder.finalizeAll().toHex();
        }

        emit(
          state.copyWith(
            transaction: ScannedTransaction(
              format: TxFormat.hex,
              data: finalTx,
              tx: await RawBitcoinTxEntity.fromBytes(hex.decode(finalTx)),
            ),
          ),
        );
      } else {
        final (tx, bbqr) = await state.bbqr.scanTransaction(payload);
        emit(state.copyWith(bbqr: bbqr));
        if (tx != null) emit(state.copyWith(transaction: tx));
      }
    } catch (e) {
      emit(state.copyWith(error: UnexpectedError(e)));
    }
  }

  Future<void> resetState() async => emit(
    BroadcastSignedTxState(bbqr: Bbqr(), unsignedPsbt: state.unsignedPsbt),
  );

  Future<void> onNfcScanned(NFCTag tag) async {
    emit(state.copyWith(error: null));
    try {
      final ndefRecords = await FlutterNfcKit.readNDEFRecords();

      if (ndefRecords.isEmpty) {
        emit(state.copyWith(error: PushTxNoNdefRecordsError()));
        return;
      }

      final payload = ndefRecords.first.toString();
      final uriRegex = RegExp('uri=([^ ]+)');
      final match = uriRegex.firstMatch(payload);

      if (match == null) {
        emit(state.copyWith(error: PushTxNoUriError()));
        return;
      }

      final uriString = match.group(1)!;
      final pushTx = Uri.parse(uriString);
      final fragmentParams = Uri.splitQueryString(pushTx.fragment);

      if (fragmentParams.isEmpty ||
          !fragmentParams.keys.contains('t') ||
          !fragmentParams.keys.contains('c')) {
        emit(state.copyWith(error: PushTxMissingFragmentParamsError()));
        return;
      }

      final txBase64Url = base64Url.normalize(fragmentParams['t']!);
      final _ = base64Url.normalize(fragmentParams['c']!);

      final txBytesHex = hex.encode(base64Url.decode(txBase64Url));

      await tryParseTransaction(txBytesHex);

      emit(state.copyWith(pushTxUri: pushTx));
    } catch (e) {
      emit(state.copyWith(error: UnexpectedError(e)));
    }
  }

  Future<void> pushTxUri() async {
    if (state.pushTxUri == null) return;

    try {
      await launchUrl(state.pushTxUri!, mode: LaunchMode.externalApplication);
      emit(state.copyWith(isBroadcasted: true));
    } catch (e) {
      emit(state.copyWith(error: UnexpectedError(e)));
    }
  }

  Future<void> tryParseTransaction(String input) async {
    emit(state.copyWith(error: null));
    try {
      final tx = await RawBitcoinTxEntity.fromPsbt(input);
      emit(
        state.copyWith(
          transaction: ParsedTx(format: TxFormat.psbt, data: input, tx: tx),
        ),
      );
    } catch (e) {
      try {
        final tx = await RawBitcoinTxEntity.fromBytes(hex.decode(input));
        emit(
          state.copyWith(
            transaction: ParsedTx(format: TxFormat.hex, data: input, tx: tx),
          ),
        );
      } catch (e) {
        emit(state.copyWith(error: InvalidTxError()));
      }
    }
  }

  Future<void> broadcastTransaction() async {
    try {
      if (state.transaction == null) return;

      await _broadcastBitcoinTransactionUsecase.execute(
        state.transaction!.data,
        isPsbt: state.transaction!.format == TxFormat.psbt,
      );
      emit(state.copyWith(isBroadcasted: true));
    } catch (e) {
      emit(state.copyWith(error: UnexpectedError(e)));
    }
  }
}
