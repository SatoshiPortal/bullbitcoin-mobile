import '../domain/usecases/load_broadcast_wallets_usecase.dart';
import '../domain/usecases/broadcast_imported_transaction_usecase.dart';
import 'package:primitives/primitives.dart';
import 'dart:convert';

import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class BroadcastSignedTxCubit extends Cubit<BroadcastSignedTxState> {
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final LoadBroadcastWalletsUsecase _loadWallets;
  late final _broadcast = BroadcastImportedTransactionUsecase(
    broadcast: _broadcastBitcoinTransactionUsecase,
  );

  BroadcastSignedTxCubit({
    required this._broadcastBitcoinTransactionUsecase,
    required this._loadWallets,
    String? unsignedPsbt,
  }) : super(BroadcastSignedTxState(bbqr: Bbqr(), unsignedPsbt: unsignedPsbt));

  Future<void> loadWallets() async {
    if (state.loadingWallets) return;
    emit(state.copyWith(loadingWallets: true));
    final result = await _loadWallets.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(wallets: value, loadingWallets: false));
      case Err(:final failure):
        emit(state.copyWith(failure: failure, loadingWallets: false));
    }
  }

  void selectSourceWallet(String walletId) {
    if (state.isBroadcasting || state.isBroadcasted) return;
    for (final wallet in state.wallets) {
      if (wallet.id == walletId) {
        emit(state.copyWith(sourceWallet: wallet, failure: null));
        return;
      }
    }
  }

  Future<void> onQrScanned(String payload) async {
    try {
      emit(state.copyWith(failure: null));
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

          final psbt = bdk.Psbt(psbtBase64: state.unsignedPsbt!);
          final signedPsbt = bdk.Psbt(psbtBase64: payload);

          final tx = psbt.combine(other: signedPsbt);
          final finalized = tx.finalize();
          if (!finalized.couldFinalize) {
            log.warning(
              'Could not finalize the combined PSBT',
              error: finalized.errors,
            );
            emit(state.copyWith(failure: const PsbtFinalizationFailure()));
            return;
          }
          finalTx = hex.encode(finalized.psbt.extractTx().serialize());
        }

        emit(
          state.copyWith(
            transaction: ScannedTransaction(
              format: TxFormat.hex,
              data: finalTx,
              tx: await BitcoinTx.fromBytes(hex.decode(finalTx)),
            ),
          ),
        );
      } else {
        final (tx, bbqr) = await state.bbqr.scanTransaction(payload);
        emit(state.copyWith(bbqr: bbqr));
        if (tx != null) emit(state.copyWith(transaction: tx));
      }
    } catch (e, st) {
      log.warning('Failed to scan QR transaction', error: e, trace: st);
      emit(state.copyWith(failure: BroadcastUnexpectedFailure(e.toString())));
    }
  }

  Future<void> resetState() async => emit(
    BroadcastSignedTxState(
      bbqr: Bbqr(),
      unsignedPsbt: state.unsignedPsbt,
      wallets: state.wallets,
    ),
  );

  Future<void> onNfcScanned(NFCTag tag) async {
    emit(state.copyWith(failure: null));
    try {
      final ndefRecords = await FlutterNfcKit.readNDEFRecords();

      if (ndefRecords.isEmpty) {
        emit(state.copyWith(failure: const InvalidPushTxFailure()));
        return;
      }

      final payload = ndefRecords.first.toString();
      final uriRegex = RegExp('uri=([^ ]+)');
      final match = uriRegex.firstMatch(payload);

      if (match == null) {
        emit(state.copyWith(failure: const InvalidPushTxFailure()));
        return;
      }

      final uriString = match.group(1)!;
      final pushTx = Uri.parse(uriString);
      if (pushTx.scheme != 'https') {
        throw FormatException('PushTx URI must use HTTPS');
      }
      final fragmentParams = Uri.splitQueryString(pushTx.fragment);

      if (fragmentParams.isEmpty ||
          !fragmentParams.keys.contains('t') ||
          !fragmentParams.keys.contains('c')) {
        emit(state.copyWith(failure: const InvalidPushTxFailure()));
        return;
      }

      final txBase64Url = base64Url.normalize(fragmentParams['t']!);
      final checksum = base64Url.normalize(fragmentParams['c']!);

      final txBytes = base64Url.decode(txBase64Url);
      final expectedChecksum = base64Url.encode(
        sha256.convert(txBytes).bytes.sublist(0, 4),
      );
      if (checksum != expectedChecksum) {
        throw FormatException('Invalid PushTx checksum');
      }
      final txBytesHex = hex.encode(txBytes);

      await tryParseTransaction(txBytesHex);

      emit(state.copyWith(pushTxUri: pushTx));
    } catch (e, st) {
      log.warning('Failed to scan NFC PushTx tag', error: e, trace: st);
      emit(state.copyWith(failure: BroadcastUnexpectedFailure(e.toString())));
    }
  }

  // PushTx carries a signed transaction. Respect the selected wallet transport instead of opening a third-party broadcast URL.
  Future<void> pushTxUri() => broadcastTransaction();

  Future<void> tryParseTransaction(String input) async {
    emit(state.copyWith(failure: null));
    try {
      final tx = await BitcoinTx.fromPsbt(input);
      emit(
        state.copyWith(
          transaction: ParsedTx(format: TxFormat.psbt, data: input, tx: tx),
        ),
      );
    } catch (e) {
      try {
        final tx = await BitcoinTx.fromBytes(hex.decode(input));
        emit(
          state.copyWith(
            transaction: ParsedTx(format: TxFormat.hex, data: input, tx: tx),
          ),
        );
      } catch (e, st) {
        log.warning(
          'Pasted input is not a valid PSBT or tx',
          error: e,
          trace: st,
        );
        emit(state.copyWith(failure: const InvalidTransactionFailure()));
      }
    }
  }

  Future<void> broadcastTransaction() async {
    if (state.isBroadcasting || state.isBroadcasted) return;
    final transaction = state.transaction;
    if (transaction == null) return;
    final wallet = state.sourceWallet;
    if (wallet == null) {
      emit(state.copyWith(failure: const SourceWalletRequiredFailure()));
      return;
    }
    emit(state.copyWith(isBroadcasting: true, failure: null));
    final result = await _broadcast.execute(
      transaction.data,
      isPsbt: transaction.format == TxFormat.psbt,
      walletId: wallet.id,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(isBroadcasted: true, isBroadcasting: false));
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isBroadcasting: false));
    }
  }
}
