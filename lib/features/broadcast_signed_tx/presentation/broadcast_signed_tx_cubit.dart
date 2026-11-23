import 'dart:convert';

import 'package:satoshifier/bbqr.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_imported_bitcoin_usecase.dart';
import 'package:sync/sync.dart' show BitcoinTx;
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/verify_broadcast_signed_tx_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:sync/sync.dart'
    show SyncNotFinalizableFailure, finalizeBitcoinPsbts;
import 'package:bitcoin_base/bitcoin_base.dart' show Psbt, PsbtBuilder;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:url_launcher/url_launcher.dart';

class BroadcastSignedTxCubit extends Cubit<BroadcastSignedTxState> {
  final BroadcastImportedBitcoinUsecase _broadcastImportedBitcoin;
  final Future<BitcoinNetwork?> capturedNetwork;
  final VerifyBroadcastSignedTxUsecase _verifySignedTxUsecase;
  final PreparedBitcoinSpend? _prepared;

  BroadcastSignedTxCubit({
    required this._broadcastImportedBitcoin,
    required this._verifySignedTxUsecase,
    PreparedBitcoinSpend? prepared,
    BitcoinNetwork? network,
  }) : _prepared = prepared,
       capturedNetwork = network != null
           ? Future.value(network)
           : _broadcastImportedBitcoin.captureNetwork(),
       super(
         BroadcastSignedTxState(
           bbqr: Bbqr(),
           unsignedPsbt: prepared?.unsignedPsbt,
         ),
       );

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
          final unsignedPsbt = state.unsignedPsbt;
          if (unsignedPsbt == null) {
            rethrow;
          }

          // Seedsigner doesn't return the original input data, so here we try to add inputs data from the unsigned tx
          switch (finalizeBitcoinPsbts(
            unsignedBase64: unsignedPsbt,
            signedBase64: payload,
          )) {
            case Ok(:final value):
              finalTx = hex.encode(value.bytes);
            case Err(failure: SyncNotFinalizableFailure()):
              log.warning('Could not finalize the combined PSBT');
              emit(state.copyWith(failure: const PsbtFinalizationFailure()));
              return;
            case Err(:final failure):
              log.warning(
                'Scanned PSBT is unreadable category=${failure.logCode}',
              );
              emit(state.copyWith(failure: const InvalidTransactionFailure()));
              return;
          }
        }
        if (!await _verifyAgainstOriginal(finalTx)) return;

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
        if (tx != null) {
          if (!await _verifyAgainstOriginal(
            tx.data,
            isPsbt: tx.format == TxFormat.psbt,
          )) {
            return;
          }
          emit(state.copyWith(transaction: tx));
        }
      }
    } on Exception catch (e, st) {
      log.warning('Failed to scan QR transaction', error: e, trace: st);
      emit(state.copyWith(failure: BroadcastUnexpectedFailure(e.toString())));
    }
  }

  Future<void> resetState() async => emit(
    BroadcastSignedTxState(bbqr: Bbqr(), unsignedPsbt: state.unsignedPsbt),
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
    } on Exception catch (e, st) {
      log.warning('Failed to scan NFC PushTx tag', error: e, trace: st);
      emit(state.copyWith(failure: BroadcastUnexpectedFailure(e.toString())));
    }
  }

  Future<void> pushTxUri() async {
    final uri = state.pushTxUri;
    if (uri == null || state.unsignedPsbt != null) return;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Unable to open PushTx URI');
      }
    } catch (e, st) {
      log.warning('Failed to open PushTx URI', error: e, trace: st);
      emit(state.copyWith(failure: BroadcastUnexpectedFailure(e.toString())));
    }
  }

  Future<void> tryParseTransaction(String input) async {
    emit(state.copyWith(failure: null));
    late final BitcoinTx tx;
    late final TxFormat format;
    try {
      tx = await BitcoinTx.fromPsbt(input);
      format = TxFormat.psbt;
    } on Exception {
      try {
        tx = await BitcoinTx.fromBytes(hex.decode(input));
        format = TxFormat.hex;
      } on Exception catch (e, st) {
        log.warning(
          'Pasted input is not a valid PSBT or tx',
          error: e,
          trace: st,
        );
        emit(state.copyWith(failure: const InvalidTransactionFailure()));
        return;
      }
    }

    // A signer such as Jade or SeedSigner returns a signed PSBT that is not
    // finalized. Extracted as is, it has no witnesses: the review would show a
    // wrong rate and the node would reject it. Finalize it as the QR path
    // does; a PSBT that cannot be finalized (unsigned, or already final) is
    // kept as it is.
    var parsed = tx;
    var parsedFormat = format;
    var data = input;
    if (format == TxFormat.psbt) {
      final finalized = _tryFinalize(input);
      if (finalized != null) {
        parsed = await BitcoinTx.fromBytes(hex.decode(finalized));
        parsedFormat = TxFormat.hex;
        data = finalized;
      }
    }

    if (!await _verifyAgainstOriginal(
      data,
      isPsbt: parsedFormat == TxFormat.psbt,
    )) {
      return;
    }
    emit(
      state.copyWith(
        transaction: ParsedTx(format: parsedFormat, data: data, tx: parsed),
      ),
    );
  }

  String? _tryFinalize(String psbtBase64) {
    try {
      return PsbtBuilder.fromPsbt(Psbt.fromBase64(psbtBase64))
          .finalizeAll()
          .toHex();
    } on Exception {
      return null;
    }
  }

  Future<bool> _verifyAgainstOriginal(
    String signedTransaction, {
    bool isPsbt = false,
  }) async {
    final unsignedPsbt = state.unsignedPsbt;
    if (unsignedPsbt == null) return true;
    final result = await _verifySignedTxUsecase.execute(
      unsignedPsbt: unsignedPsbt,
      signedTransaction: signedTransaction,
      isPsbt: isPsbt,
    );
    if (isClosed || state.unsignedPsbt != unsignedPsbt) return false;
    switch (result) {
      case Ok():
        return true;
      case Err(:final failure):
        log.warning(
          'Signed transaction does not match the exported PSBT',
          error: failure.logMessage,
        );
        emit(state.copyWith(failure: failure));
        return false;
    }
  }

  Future<void> broadcastTransaction() async {
    final transaction = state.transaction;
    if (state.isBroadcasting ||
        state.isBroadcasted ||
        transaction == null ||
        state.unsignedPsbt != null) {
      return;
    }
    // Clear any error from a previous failed attempt so the stale message
    // doesn't linger under the spinner while the retry is in flight.
    emit(state.copyWith(isBroadcasting: true, failure: null));
    final result = await _broadcastImportedBitcoin.execute(
      transaction: transaction.data,
      isPsbt: transaction.format == TxFormat.psbt,
      network: await capturedNetwork,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(isBroadcasted: true, isBroadcasting: false));
      case Err(:final failure):
        log.warning(
          'Signed transaction broadcast failed category=${failure.runtimeType}',
        );
        emit(state.copyWith(failure: failure, isBroadcasting: false));
    }
  }

  /// The Send reader never broadcasts. Finalize the signed transaction, then
  /// verify it again before returning it to the owner of the original PSBT.
  Future<String?> signedForSend() async {
    final prepared = _prepared;
    final transaction = state.transaction;
    if (prepared == null || transaction == null) return null;
    final String signed;
    if (transaction.format == TxFormat.psbt) {
      switch (finalizeBitcoinPsbts(
        unsignedBase64: prepared.unsignedPsbt,
        signedBase64: transaction.data,
      )) {
        case Ok(:final value):
          signed = hex.encode(value.bytes);
        case Err():
          emit(state.copyWith(failure: const PsbtFinalizationFailure()));
          return null;
      }
    } else {
      signed = transaction.data;
    }
    final verified = await _verifySignedTxUsecase.verifyPrepared(
      prepared: prepared,
      signedTransaction: signed,
    );
    if (isClosed || !identical(state.transaction, transaction)) {
      return null;
    }
    switch (verified) {
      case Ok():
        return signed;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return null;
    }
  }
}
