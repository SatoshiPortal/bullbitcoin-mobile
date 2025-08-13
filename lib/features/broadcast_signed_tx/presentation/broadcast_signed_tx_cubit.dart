import 'dart:convert';

import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/errors.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:convert/convert.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:url_launcher/url_launcher.dart';

class BroadcastSignedTxCubit extends Cubit<BroadcastSignedTxState> {
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;

  BroadcastSignedTxCubit({
    required BroadcastBitcoinTransactionUsecase
    broadcastBitcoinTransactionUsecase,
  }) : _broadcastBitcoinTransactionUsecase = broadcastBitcoinTransactionUsecase,
       super(BroadcastSignedTxState(bbqr: Bbqr()));

  Future<void> onQrScanned(String payload) async {
    try {
      emit(state.copyWith(error: null));
      final tx = await state.bbqr.scanTransaction(payload);
      if (tx != null) emit(state.copyWith(transaction: tx));
    } catch (e) {
      emit(state.copyWith(error: UnexpectedError(e)));
    }
  }

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
          transaction: (format: TxFormat.psbt, data: input, tx: tx),
        ),
      );
    } catch (e) {
      try {
        final tx = await RawBitcoinTxEntity.fromBytes(hex.decode(input));
        emit(
          state.copyWith(
            transaction: (format: TxFormat.hex, data: input, tx: tx),
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
